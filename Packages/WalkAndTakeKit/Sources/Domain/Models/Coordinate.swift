//
//  Coordinate.swift
//  WalkAndTakeKit
//
//  Plain latitude/longitude so Domain stays free of CoreLocation.
//

import Foundation

public struct Coordinate: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    static let earthRadiusMiles = 3958.8

    /// Great-circle (haversine) distance in miles.
    public func distanceMiles(to other: Coordinate) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * Self.earthRadiusMiles * asin(min(1, sqrt(a)))
    }
}
