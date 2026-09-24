//
//  CustomerShell.swift
//  WakeAndTake
//
//  Assembles the customer tabs. During Phase 4, tabs that haven't been ported yet
//  host their legacy draft views; each sub-phase swaps one in for its new screen.
//

import CustomerFeatures
import Platform
import SwiftUI

struct CustomerShell: View {
    let dependencies: AppDependencies

    var body: some View {
        let navigation = dependencies.navigation
        let legacy = dependencies.legacyStore

        CustomerTabView(navigation: navigation, ordersBadge: legacyActiveOrders) {
            DiscoverView(store: legacy)
        } orders: {
            OrdersView(store: legacy) { navigation.selectedTab = .discover }
        } favorites: {
            FavoritesView(store: legacy) { navigation.selectedTab = .discover }
        } profile: {
            ProfileView(store: legacy)
        }
    }

    /// Legacy badge until Orders is ported (4d).
    private var legacyActiveOrders: Int {
        let now = dependencies.clock.now
        return dependencies.legacyStore.reservations.filter { $0.isActive(at: now) }.count
    }
}
