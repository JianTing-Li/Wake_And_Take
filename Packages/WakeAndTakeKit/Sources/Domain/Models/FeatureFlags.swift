//
//  FeatureFlags.swift
//  WakeAndTakeKit
//
//  Defaults are set by the app target (FeatureFlags+Default.swift).
//  A flag that's off hides UI entry points; code and data stay.
//

import Foundation

public struct FeatureFlags: Hashable, Sendable {
    public var mapBrowse: Bool
    public var favorites: Bool
    public var notifications: Bool
    public var dietaryFilters: Bool
    public var manageOrder: Bool
    public var reviews: Bool
    public var impact: Bool
    public var commute: Bool

    public init(
        mapBrowse: Bool,
        favorites: Bool,
        notifications: Bool,
        dietaryFilters: Bool,
        manageOrder: Bool,
        reviews: Bool,
        impact: Bool,
        commute: Bool
    ) {
        self.mapBrowse = mapBrowse
        self.favorites = favorites
        self.notifications = notifications
        self.dietaryFilters = dietaryFilters
        self.manageOrder = manageOrder
        self.reviews = reviews
        self.impact = impact
        self.commute = commute
    }

    /// Alerts are tied to favorite restaurants, so they need both flags.
    public var alertsEnabled: Bool { notifications && favorites }
}
