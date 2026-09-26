//
//  Restaurant.swift
//  WalkAndTakeKit
//

import Foundation

/// A business that lists surprise bags.
public struct Restaurant: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, CaseIterable, Codable, Sendable {
        case cafe, bakery, deli, restaurant, market
    }

    public struct Address: Hashable, Codable, Sendable {
        public var street: String
        public var crossStreet: String
        public var neighborhood: String
        public var borough: String
        public var zip: String

        public init(street: String, crossStreet: String, neighborhood: String, borough: String, zip: String) {
            self.street = street
            self.crossStreet = crossStreet
            self.neighborhood = neighborhood
            self.borough = borough
            self.zip = zip
        }

        /// "Vernon Blvd & 48th Ave"
        public var intersection: String { "\(street) & \(crossStreet)" }

        /// "Vernon Blvd & 48th Ave, Long Island City"
        public var shortLine: String { "\(intersection), \(neighborhood)" }

        /// A query Apple Maps can resolve for directions.
        public var mapsQuery: String { "\(street) & \(crossStreet), \(borough), NY \(zip)" }
    }

    public let id: String
    public var name: String
    public var kind: Kind
    public var address: Address
    public var coordinate: Coordinate
    public var pickupInstructions: String
    public var rating: Double
    public var reviewCount: Int

    public init(
        id: String,
        name: String,
        kind: Kind,
        address: Address,
        coordinate: Coordinate,
        pickupInstructions: String,
        rating: Double,
        reviewCount: Int
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.address = address
        self.coordinate = coordinate
        self.pickupInstructions = pickupInstructions
        self.rating = rating
        self.reviewCount = reviewCount
    }
}
