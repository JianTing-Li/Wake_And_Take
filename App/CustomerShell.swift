//
//  CustomerShell.swift
//  WakeAndTake
//
//  Assembles the customer tabs from CustomerScreens.
//

import CustomerFeatures
import SwiftUI

struct CustomerShell: View {
    let dependencies: AppDependencies

    var body: some View {
        let screens = dependencies.screens

        CustomerTabView(navigation: dependencies.navigation, ordersBadge: screens.ordersBadge) {
            screens.discoverTab()
        } orders: {
            screens.ordersTab()
        } favorites: {
            screens.favoritesTab()
        } profile: {
            screens.profileTab()
        }
        .task { await screens.runBackground() }
    }
}
