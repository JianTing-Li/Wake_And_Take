//
//  CustomerTabView.swift
//  WakeAndTakeKit
//
//  The customer's four tabs. The composition root supplies each tab's root screen.
//

import DesignSystem
import Domain
import SwiftUI

public struct CustomerTabView<Discover: View, Orders: View, Favorites: View, Profile: View>: View {
    @Bindable var navigation: CustomerNavigation
    let ordersBadge: Int
    let discover: Discover
    let orders: Orders
    let favorites: Favorites
    let profile: Profile

    @Environment(\.featureFlags) private var flags

    public init(
        navigation: CustomerNavigation,
        ordersBadge: Int,
        @ViewBuilder discover: () -> Discover,
        @ViewBuilder orders: () -> Orders,
        @ViewBuilder favorites: () -> Favorites,
        @ViewBuilder profile: () -> Profile
    ) {
        self.navigation = navigation
        self.ordersBadge = ordersBadge
        self.discover = discover()
        self.orders = orders()
        self.favorites = favorites()
        self.profile = profile()
    }

    public var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab("Discover", systemImage: "magnifyingglass", value: CustomerTab.discover) {
                discover
            }
            Tab("Orders", systemImage: "bag.fill", value: CustomerTab.orders) {
                orders
            }
            .badge(ordersBadge)
            if flags.favorites {
                Tab("Favorites", systemImage: "heart.fill", value: CustomerTab.favorites) {
                    favorites
                }
            }
            Tab("Profile", systemImage: "person.crop.circle", value: CustomerTab.profile) {
                profile
            }
        }
        .tint(.splashTeal)
        .onChange(of: flags.favorites, initial: true) {
            if !CustomerTab.visible(with: flags).contains(navigation.selectedTab) {
                navigation.selectedTab = .discover
            }
        }
    }
}

#Preview("Light") {
    CustomerTabView(navigation: CustomerNavigation(), ordersBadge: 2) {
        Text("Discover")
    } orders: {
        Text("Orders")
    } favorites: {
        Text("Favorites")
    } profile: {
        Text("Profile")
    }
}

#Preview("Favorites off · dark") {
    CustomerTabView(navigation: CustomerNavigation(), ordersBadge: 0) {
        Text("Discover")
    } orders: {
        Text("Orders")
    } favorites: {
        Text("Favorites")
    } profile: {
        Text("Profile")
    }
    .environment(
        \.featureFlags,
        FeatureFlags(
            mapBrowse: true, favorites: false, notifications: true, dietaryFilters: true,
            manageOrder: true, reviews: true, impact: true, commute: false)
    )
    .preferredColorScheme(.dark)
}
