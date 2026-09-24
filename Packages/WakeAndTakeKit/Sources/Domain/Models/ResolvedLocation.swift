//
//  ResolvedLocation.swift
//  WakeAndTakeKit
//

import Foundation

/// Where distances are measured from: the device, or the LIC service area
/// center when the device location can't be used.
public struct ResolvedLocation: Hashable, Sendable {
    public enum FallbackReason: Hashable, Sendable {
        /// Location permission denied or restricted.
        case permissionDenied
        /// No fix arrived in time.
        case noFix
        /// Location isn't available (e.g. a simulator with no location set).
        case unavailable
        /// The device is outside the service area.
        case outOfServiceArea
    }

    public enum Source: Hashable, Sendable {
        case device
        case fallback(FallbackReason)
    }

    public var coordinate: Coordinate
    public var source: Source

    public init(coordinate: Coordinate, source: Source) {
        self.coordinate = coordinate
        self.source = source
    }

    public init(latitude: Double, longitude: Double, source: Source) {
        self.init(coordinate: Coordinate(latitude: latitude, longitude: longitude), source: source)
    }

    public var isFallback: Bool {
        if case .fallback = source { true } else { false }
    }
}
