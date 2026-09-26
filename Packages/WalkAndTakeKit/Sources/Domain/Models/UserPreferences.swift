//
//  UserPreferences.swift
//  WalkAndTakeKit
//

import Foundation

/// Who the customer is and which bags they want to see.
public struct UserPreferences: Hashable, Codable, Sendable {
    public var name: String
    public var homeArea: String
    public var maxDistanceMiles: Double
    public var dietary: Set<DietaryTag>

    public static let distanceOptions: [Double] = [0.25, 0.5, 1.0, 1.5, 2.0]

    public init(
        name: String = "",
        homeArea: String = "Long Island City",
        maxDistanceMiles: Double = 1.0,
        dietary: Set<DietaryTag> = []
    ) {
        self.name = name
        self.homeArea = homeArea
        self.maxDistanceMiles = maxDistanceMiles
        self.dietary = dietary
    }
}
