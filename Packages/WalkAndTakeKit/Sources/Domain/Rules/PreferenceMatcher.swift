//
//  PreferenceMatcher.swift
//  WalkAndTakeKit
//

import Foundation

/// Whether an offer suits the customer's distance and dietary preferences.
public enum PreferenceMatcher {
    public static func distanceMiles(to restaurant: Coordinate, from location: ResolvedLocation) -> Double {
        location.coordinate.distanceMiles(to: restaurant)
    }

    public static func isWithinDistance(
        _ restaurant: Coordinate,
        of location: ResolvedLocation,
        preferences: UserPreferences
    ) -> Bool {
        distanceMiles(to: restaurant, from: location) <= preferences.maxDistanceMiles
    }

    /// Every selected diet must be one the bag suits.
    public static func suitsDiet(_ offer: Offer, preferences: UserPreferences) -> Bool {
        preferences.dietary.isSubset(of: offer.dietary)
    }

    /// Close enough, and (when dietary filters are on) suits every selected diet.
    public static func matches(
        _ offer: Offer,
        restaurant: Coordinate,
        location: ResolvedLocation,
        preferences: UserPreferences,
        dietaryFiltersEnabled: Bool
    ) -> Bool {
        isWithinDistance(restaurant, of: location, preferences: preferences)
            && (!dietaryFiltersEnabled || suitsDiet(offer, preferences: preferences))
    }
}
