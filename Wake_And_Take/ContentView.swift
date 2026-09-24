//
//  ContentView.swift
//  Wake_And_Take
//
//  Created by Jian Ting Li on 9/23/26.
//

import DesignSystem
import SwiftUI

struct ContentView: View {
    @State private var store = BagStore()
    @State private var selectedTab: AppTab = .discover

    enum AppTab { case discover, orders, favorites, profile }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Discover", systemImage: "magnifyingglass", value: .discover) {
                DiscoverView(store: store)
            }
            Tab("Orders", systemImage: "bag.fill", value: .orders) {
                OrdersView(store: store) { selectedTab = .discover }
            }
            .badge(store.reservations.filter { $0.isActive(at: .now) }.count)
            Tab("Favorites", systemImage: "heart.fill", value: .favorites) {
                FavoritesView(store: store) { selectedTab = .discover }
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfileView(store: store)
            }
        }
        .tint(.splashTeal)
    }
}

#Preview {
    ContentView()
}
