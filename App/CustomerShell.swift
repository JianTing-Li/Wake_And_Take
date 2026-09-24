//
//  CustomerShell.swift
//  WakeAndTake
//
//  Assembles the customer tabs. During Phase 4, tabs that haven't been ported yet
//  host their legacy draft views; each sub-phase swaps one in for its new screen.
//

import CustomerFeatures
import SwiftUI

struct CustomerShell: View {
    let dependencies: AppDependencies

    var body: some View {
        let navigation = dependencies.navigation
        let screens = dependencies.screens
        let legacy = dependencies.legacyStore

        CustomerTabView(navigation: navigation, ordersBadge: screens.ordersBadge) {
            screens.discoverTab()
        } orders: {
            screens.ordersTab()
        } favorites: {
            FavoritesView(store: legacy) { navigation.selectedTab = .discover }
        } profile: {
            ProfileView(store: legacy)
        }
        .task { await screens.runBackground() }
    }
}
