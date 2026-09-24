//
//  CustomerScreens.swift
//  WakeAndTakeKit
//
//  Builds customer screens and their view models from protocol dependencies.
//  The app creates one and asks it for each tab's root.
//

import SwiftUI

@MainActor
public final class CustomerScreens {
    public let navigation: CustomerNavigation
    public let discover: DiscoverModel
    /// Lives for the app's lifetime so the Orders badge stays current.
    public let orders: OrdersModel
    public let favorites: FavoritesModel
    private let dependencies: CustomerDependencies

    public init(dependencies: CustomerDependencies, navigation: CustomerNavigation) {
        self.dependencies = dependencies
        self.navigation = navigation
        discover = DiscoverModel(dependencies: dependencies)
        orders = OrdersModel(dependencies: dependencies)
        favorites = FavoritesModel(dependencies: dependencies)
    }

    /// Work that runs while the app is open, independent of which tab is showing.
    public func runBackground() async {
        await orders.run()
    }

    public var ordersBadge: Int { orders.activeCount }

    public func discoverTab() -> some View {
        DiscoverView(model: discover, navigation: navigation) { [unowned self] route in
            destination(for: route)
        }
    }

    public func favoritesTab() -> some View {
        FavoritesView(model: favorites, navigation: navigation) { [unowned self] route in
            switch route {
            case .offer(let id): offerDetail(id)
            }
        }
    }

    public func ordersTab() -> some View {
        OrdersView(model: orders, navigation: navigation) { [unowned self] route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func destination(for route: OrdersRoute) -> some View {
        switch route {
        case .pickup(let id):
            PickupView(
                model: PickupModel(reservationID: id, origin: discover.origin, dependencies: dependencies)
            ) { request in
                RateOrderPlaceholderView(request: request)
            }
        case .manageOrder(let id):
            ManageOrderView(model: ManageOrderModel(reservationID: id, dependencies: dependencies))
        }
    }

    private func offerDetail(_ id: String) -> some View {
        OfferDetailView(
            model: OfferDetailModel(
                offerID: id, origin: discover.origin, dependencies: dependencies, navigation: navigation))
    }

    @ViewBuilder
    private func destination(for route: DiscoverRoute) -> some View {
        switch route {
        case .offer(let id):
            offerDetail(id)
        }
    }
}
