//
//  CustomerNavigation.swift
//  WalkAndTakeKit
//

import Foundation
import Observation

/// The selected tab and each tab's navigation path.
@Observable
@MainActor
public final class CustomerNavigation {
    public var selectedTab: CustomerTab = .discover
    public var discoverPath: [DiscoverRoute] = []
    public var ordersPath: [OrdersRoute] = []
    public var favoritesPath: [FavoritesRoute] = []
    public var profilePath: [ProfileRoute] = []

    public init() {}

    /// Pops every tab to its root (after "Reset demo data"). The selected tab stays.
    public func popAllToRoot() {
        discoverPath = []
        ordersPath = []
        favoritesPath = []
        profilePath = []
    }

    /// Switches to Orders and opens the reservation's pickup screen.
    public func showOrder(_ reservationID: UUID) {
        ordersPath = [.pickup(reservationID: reservationID)]
        selectedTab = .orders
    }
}
