//
//  OrdersView.swift
//  WakeAndTakeKit
//

import DesignSystem
import Domain
import SwiftUI

public struct OrdersView<Destination: View>: View {
    let model: OrdersModel
    @Bindable var navigation: CustomerNavigation
    let destination: (OrdersRoute) -> Destination

    public init(
        model: OrdersModel,
        navigation: CustomerNavigation,
        @ViewBuilder destination: @escaping (OrdersRoute) -> Destination
    ) {
        self.model = model
        self.navigation = navigation
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: $navigation.ordersPath) {
            content
                .navigationTitle("Orders")
                .navigationDestination(for: OrdersRoute.self, destination: destination)
        }
        .tint(.splashTeal)
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
            ) { Task { await model.retry() } }
        case .loaded, .empty:
            List {
                if model.showsImpact {
                    Section {
                        ImpactCard(impact: model.impact)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if model.state == .empty {
                    EmptyStateView(
                        "No orders yet", systemImage: "bag",
                        message: "Reserve a surprise bag and it will show up here with your pickup code.",
                        actionTitle: "Find food nearby"
                    ) { navigation.selectedTab = .discover }
                    .listRowBackground(Color.clear)
                }

                ForEach(model.activeGroups) { group in
                    Section {
                        ForEach(group.rows) { row in
                            NavigationLink(value: OrdersRoute.pickup(reservationID: row.id)) { OrderRow(content: row) }
                        }
                    } header: {
                        DayLabel("Upcoming · \(group.title)", day: group.day)
                            .textCase(nil)
                    }
                }

                if !model.past.isEmpty {
                    Section("Past orders") {
                        ForEach(model.past) { row in
                            NavigationLink(value: OrdersRoute.pickup(reservationID: row.id)) { OrderRow(content: row) }
                        }
                    }
                }
            }
        }
    }
}
