//
//  FavoritesView.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import SwiftUI
import UIKit

public struct FavoritesView<Destination: View>: View {
    @Bindable var model: FavoritesModel
    @Bindable var navigation: CustomerNavigation
    let destination: (FavoritesRoute) -> Destination

    @Environment(\.openURL) private var openURL

    public init(
        model: FavoritesModel,
        navigation: CustomerNavigation,
        @ViewBuilder destination: @escaping (FavoritesRoute) -> Destination
    ) {
        self.model = model
        self.navigation = navigation
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: $navigation.favoritesPath) {
            content
                .navigationTitle("Favorites")
                .navigationDestination(for: FavoritesRoute.self, destination: destination)
                .alert("Notifications are off", isPresented: $model.notificationsBlocked) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    Button("Not now", role: .cancel) {}
                } message: {
                    Text("Allow notifications for Walk & Take in Settings to get alerts from your favorite stores.")
                }
        }
        .tint(.splashTeal)
        .task { await model.run() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            EmptyStateView(
                "Something went wrong", systemImage: "exclamationmark.triangle", message: message,
                actionTitle: "Try again"
            ) { Task { await model.load() } }
        case .empty:
            EmptyStateView(
                "No favorites yet", systemImage: "heart",
                message: model.showsAlerts
                    ? "Tap the heart on any store to save it here. Turn on alerts to hear when it has bags."
                    : "Tap the heart on any store to save it here.",
                actionTitle: "Browse stores"
            ) { navigation.selectedTab = .discover }
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(model.rows) { row in
                    rowView(row)
                }
                .onDelete { offsets in
                    let ids = offsets.map { model.rows[$0].restaurantID }
                    Task { await model.remove(ids) }
                }
            } header: {
                Text("Your stores")
            } footer: {
                if model.showsAlerts {
                    Text("Tap the bell to get a notification when a store's bags open for pickup.")
                }
            }

            if model.showsAlerts {
                Section {
                    Button {
                        Task { await model.sendPreview() }
                    } label: {
                        Label(model.previewSent ? "Alert on its way…" : "Preview an alert", systemImage: "bell.badge")
                    }
                } footer: {
                    Text("Sends a sample alert in 5 seconds so you can see what it looks like.")
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: FavoritesModel.Row) -> some View {
        let label = FavoriteStoreRow(row: row, showsBell: model.showsAlerts) {
            Task { await model.toggleAlerts(for: row.restaurantID) }
        }
        if let offerID = row.nextOfferID {
            NavigationLink(value: FavoritesRoute.offer(id: offerID)) { label }
        } else {
            // Leave room where the chevron would be so bells line up.
            label.padding(.trailing, 19)
        }
    }
}
