//
//  NavigationTests.swift
//  CustomerFeaturesTests
//

import Domain
import Foundation
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Navigation")
struct NavigationTests {
    static func flags(favorites: Bool = true) -> FeatureFlags {
        FeatureFlags(
            mapBrowse: true, favorites: favorites, notifications: true, dietaryFilters: true,
            manageOrder: true, reviews: true, impact: true, commute: false)
    }

    @Test func allFourTabsByDefault() {
        #expect(CustomerTab.visible(with: Self.flags()) == [.discover, .orders, .favorites, .profile])
    }

    @Test func favoritesFlagOffHidesTheTab() {
        #expect(CustomerTab.visible(with: Self.flags(favorites: false)) == [.discover, .orders, .profile])
    }

    @Test func popAllToRootClearsEveryPathButKeepsTheTab() {
        let nav = CustomerNavigation()
        nav.selectedTab = .profile
        nav.discoverPath = [.offer(id: "a")]
        nav.ordersPath = [.pickup(reservationID: UUID()), .manageOrder(reservationID: UUID())]
        nav.favoritesPath = [.offer(id: "b")]
        nav.profilePath = [.timeTravel]
        nav.popAllToRoot()
        #expect(nav.discoverPath.isEmpty && nav.ordersPath.isEmpty)
        #expect(nav.favoritesPath.isEmpty && nav.profilePath.isEmpty)
        #expect(nav.selectedTab == .profile)
    }

    @Test func showOrderSwitchesToOrdersAtThePickupScreen() {
        let nav = CustomerNavigation()
        let id = UUID()
        nav.ordersPath = [.manageOrder(reservationID: UUID())]
        nav.showOrder(id)
        #expect(nav.selectedTab == .orders)
        #expect(nav.ordersPath == [.pickup(reservationID: id)])
    }
}
