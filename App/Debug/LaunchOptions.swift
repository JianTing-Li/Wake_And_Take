//
//  LaunchOptions.swift
//  WakeAndTake
//
//  DEBUG launch arguments for UI tests and demos:
//    -UITestInMemoryStore            fresh in-memory data every launch
//    -UITestNow 2026-09-24T08:00:00-04:00   freeze the clock at an ISO 8601 instant
//    -UITestFixedLocation            use the LIC center as a device fix (no permission prompt)
//    -UITestSkipSplash               start on the tabs (UI tests can't reliably wait out the animation)
//

#if DEBUG
    import Domain
    import Foundation
    import Platform

    struct LaunchOptions {
        var inMemoryStore = false
        var fixedNow: Date?
        var fixedLocation = false
        var skipSplash = false

        static var current: LaunchOptions {
            LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
        }

        init(arguments: [String]) {
            inMemoryStore = arguments.contains("-UITestInMemoryStore")
            fixedLocation = arguments.contains("-UITestFixedLocation")
            skipSplash = arguments.contains("-UITestSkipSplash")
            if let index = arguments.firstIndex(of: "-UITestNow"), arguments.indices.contains(index + 1) {
                fixedNow = try? Date(arguments[index + 1], strategy: .iso8601)
            }
        }
    }

    /// Always "at" the service-area center, as if the device reported it.
    struct FixedLocationProvider: LocationProvider {
        func resolve() async -> ResolvedLocation {
            ResolvedLocation(coordinate: ServiceArea.longIslandCity.center, source: .device)
        }
    }
#endif
