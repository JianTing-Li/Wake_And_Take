//
//  CoreLocationSource.swift
//  WalkAndTakeKit
//
//  Live readings via CLServiceSession + CLLocationUpdate.liveUpdates.
//  Requires NSLocationWhenInUseUsageDescription in the app's Info.plist.
//

import CoreLocation
import Domain
import Foundation

public struct CoreLocationSource: LocationSource {
    public init() {}

    public func readings() -> AsyncStream<LocationReading> {
        AsyncStream { continuation in
            let task = Task {
                // Holding the session asks for When In Use authorization and keeps it active.
                let session = CLServiceSession(authorization: .whenInUse)
                defer { session.invalidate() }
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let reading = Self.reading(from: update) {
                            continuation.yield(reading)
                        }
                    }
                } catch {
                    continuation.yield(.unavailable)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func reading(from update: CLLocationUpdate) -> LocationReading? {
        if update.authorizationDenied || update.authorizationDeniedGlobally { return .denied }
        if update.authorizationRestricted { return .restricted }
        if update.authorizationRequestInProgress { return .authorizing }
        if let location = update.location {
            return .location(
                Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            )
        }
        if update.locationUnavailable { return .unavailable }
        return nil
    }
}
