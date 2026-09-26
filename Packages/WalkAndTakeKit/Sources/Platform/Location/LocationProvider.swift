//
//  LocationProvider.swift
//  WalkAndTakeKit
//

import Domain
import Foundation
import Synchronization

/// Resolves where distances are measured from.
public protocol LocationProvider: Sendable {
    func resolve() async -> ResolvedLocation
}

/// One reading from a location source.
public enum LocationReading: Hashable, Sendable {
    /// The permission prompt is showing; the fix timeout is paused.
    case authorizing
    case denied
    case restricted
    /// Location services can't produce a fix right now (e.g. simulator with no location).
    case unavailable
    case location(Coordinate)
}

/// Produces raw readings; `CoreLocationSource` in the app, a fake in tests.
public protocol LocationSource: Sendable {
    func readings() -> AsyncStream<LocationReading>
}

/// Resolves the device location, falling back to the service-area center when the
/// permission is denied, no fix arrives in time, location is unavailable, or the
/// device is outside the service area.
public struct DeviceLocationProvider: LocationProvider {
    private let source: any LocationSource
    private let serviceArea: ServiceArea
    private let fixTimeout: Duration

    public init(
        source: any LocationSource,
        serviceArea: ServiceArea = .longIslandCity,
        fixTimeout: Duration = .seconds(5)
    ) {
        self.source = source
        self.serviceArea = serviceArea
        self.fixTimeout = fixTimeout
    }

    public func resolve() async -> ResolvedLocation {
        switch await firstDecisiveReading() {
        case .location(let coordinate):
            serviceArea.contains(coordinate)
                ? ResolvedLocation(coordinate: coordinate, source: .device)
                : serviceArea.fallback(.outOfServiceArea)
        case .denied, .restricted:
            serviceArea.fallback(.permissionDenied)
        case .unavailable:
            serviceArea.fallback(.unavailable)
        case .authorizing, nil:
            serviceArea.fallback(.noFix)
        }
    }

    /// The first fix or permission refusal. On timeout, returns `.unavailable` if the
    /// source said so along the way, otherwise nil ("no fix").
    private func firstDecisiveReading() async -> LocationReading? {
        let state = ReadingState()
        let readings = source.readings()
        let timeout = fixTimeout

        return await withTaskGroup(of: LocationReading?.self) { group in
            group.addTask {
                for await reading in readings {
                    state.record(reading)
                    switch reading {
                    case .location, .denied, .restricted: return reading
                    case .authorizing, .unavailable: continue
                    }
                }
                return state.lastInconclusive
            }
            group.addTask {
                // The timeout restarts while the permission prompt is up.
                repeat {
                    try? await Task.sleep(for: timeout)
                } while state.isAuthorizing && !Task.isCancelled
                return state.lastInconclusive
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

/// What the reading task has seen so far, shared with the timeout task.
private final class ReadingState: Sendable {
    private struct Snapshot {
        var isAuthorizing = false
        var sawUnavailable = false
    }

    private let snapshot = Mutex(Snapshot())

    func record(_ reading: LocationReading) {
        snapshot.withLock {
            $0.isAuthorizing = reading == .authorizing
            if reading == .unavailable { $0.sawUnavailable = true }
        }
    }

    var isAuthorizing: Bool { snapshot.withLock { $0.isAuthorizing } }

    /// `.unavailable` if the source reported it, otherwise nil (plain "no fix").
    var lastInconclusive: LocationReading? {
        snapshot.withLock { $0.sawUnavailable ? .unavailable : nil }
    }
}
