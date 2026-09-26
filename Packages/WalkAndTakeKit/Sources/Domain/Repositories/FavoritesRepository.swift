//
//  FavoritesRepository.swift
//  WalkAndTakeKit
//

import Foundation

/// A saved restaurant and whether the customer wants alerts from it.
public struct FavoriteRestaurant: Hashable, Sendable {
    public var restaurantID: String
    public var alertsEnabled: Bool

    public init(restaurantID: String, alertsEnabled: Bool) {
        self.restaurantID = restaurantID
        self.alertsEnabled = alertsEnabled
    }
}

/// Favorites are keyed by restaurant ID. Notification permission is the caller's job.
public protocol FavoritesRepository: Sendable {
    func favorites() async throws -> [FavoriteRestaurant]
    /// Adds or removes a favorite. Removing also turns its alerts off.
    func setFavorite(_ isFavorite: Bool, restaurantID: String) async throws
    /// Turns alerts on or off. Turning them on also favorites the restaurant.
    func setAlerts(_ enabled: Bool, restaurantID: String) async throws
    func changes() -> AsyncStream<UserDataChange>
}
