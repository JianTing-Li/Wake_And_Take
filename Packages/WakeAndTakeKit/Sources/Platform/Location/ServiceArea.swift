//
//  ServiceArea.swift
//  WakeAndTakeKit
//

import Domain
import Foundation

/// Where Wake&Take operates. Outside it, distances are measured from the center.
public struct ServiceArea: Hashable, Sendable {
    public var center: Coordinate
    public var radiusMiles: Double

    public init(center: Coordinate, radiusMiles: Double) {
        self.center = center
        self.radiusMiles = radiusMiles
    }

    /// Long Island City, Queens.
    public static let longIslandCity = ServiceArea(
        center: Coordinate(latitude: 40.7455, longitude: -73.9490),
        radiusMiles: 1.5
    )

    public func contains(_ coordinate: Coordinate) -> Bool {
        center.distanceMiles(to: coordinate) <= radiusMiles
    }

    public func fallback(_ reason: ResolvedLocation.FallbackReason) -> ResolvedLocation {
        ResolvedLocation(coordinate: center, source: .fallback(reason))
    }
}
