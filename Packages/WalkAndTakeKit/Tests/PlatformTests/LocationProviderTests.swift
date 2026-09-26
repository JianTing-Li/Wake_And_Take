//
//  LocationProviderTests.swift
//  PlatformTests
//

import Domain
import Foundation
import Testing

@testable import Platform

/// Replays scripted readings, optionally leaving the stream open (no more readings).
struct FakeLocationSource: LocationSource {
    var script: [LocationReading]
    var staysOpen = true

    func readings() -> AsyncStream<LocationReading> {
        AsyncStream { continuation in
            for reading in script { continuation.yield(reading) }
            if !staysOpen { continuation.finish() }
        }
    }
}

/// Emits `.authorizing` for a while, then a fix.
struct SlowPromptSource: LocationSource {
    var promptDuration: Duration
    var fix: Coordinate

    func readings() -> AsyncStream<LocationReading> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(.authorizing)
                try? await Task.sleep(for: promptDuration)
                continuation.yield(.location(fix))
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@Suite("Location fallback")
struct LocationProviderTests {
    let area = ServiceArea.longIslandCity
    /// Court Square, inside LIC.
    let insideLIC = Coordinate(latitude: 40.7470, longitude: -73.9440)
    /// Times Square, ~2.4 mi away.
    let midtown = Coordinate(latitude: 40.7580, longitude: -73.9855)

    func provider(_ source: any LocationSource) -> DeviceLocationProvider {
        DeviceLocationProvider(source: source, serviceArea: area, fixTimeout: .milliseconds(100))
    }

    @Test func deviceFixInsideServiceArea() async {
        let resolved = await provider(FakeLocationSource(script: [.location(insideLIC)])).resolve()
        #expect(resolved == ResolvedLocation(coordinate: insideLIC, source: .device))
    }

    @Test func permissionDenied() async {
        let resolved = await provider(FakeLocationSource(script: [.authorizing, .denied])).resolve()
        #expect(resolved == area.fallback(.permissionDenied))
        #expect(resolved.coordinate == Coordinate(latitude: 40.7455, longitude: -73.9490))
    }

    @Test func permissionRestricted() async {
        let resolved = await provider(FakeLocationSource(script: [.restricted])).resolve()
        #expect(resolved.source == .fallback(.permissionDenied))
    }

    @Test func noFixWithinTimeout() async {
        let resolved = await provider(FakeLocationSource(script: [])).resolve()
        #expect(resolved.source == .fallback(.noFix))
    }

    @Test func unavailableLikeASimulatorWithNoLocation() async {
        let resolved = await provider(FakeLocationSource(script: [.unavailable])).resolve()
        #expect(resolved.source == .fallback(.unavailable))
    }

    @Test func transientUnavailableThenFixUsesTheFix() async {
        let resolved = await provider(FakeLocationSource(script: [.unavailable, .location(insideLIC)])).resolve()
        #expect(resolved.source == .device)
    }

    @Test func outsideServiceArea() async {
        let resolved = await provider(FakeLocationSource(script: [.location(midtown)])).resolve()
        #expect(resolved == area.fallback(.outOfServiceArea))
    }

    @Test func sourceEndingWithoutAFixIsNoFix() async {
        let resolved = await provider(FakeLocationSource(script: [], staysOpen: false)).resolve()
        #expect(resolved.source == .fallback(.noFix))
    }

    @Test func timeoutPausesWhileThePermissionPromptIsUp() async {
        // The prompt takes 3× the timeout; the fix after it still counts.
        let source = SlowPromptSource(promptDuration: .milliseconds(300), fix: insideLIC)
        let resolved = await provider(source).resolve()
        #expect(resolved.source == .device)
    }

    @Test func serviceAreaEdges() {
        #expect(area.contains(area.center))
        #expect(area.contains(insideLIC))
        #expect(!area.contains(midtown))
        #expect(area.radiusMiles == 1.5)
    }
}
