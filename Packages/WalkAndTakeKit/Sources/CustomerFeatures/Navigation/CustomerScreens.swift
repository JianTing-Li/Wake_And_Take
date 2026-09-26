//
//  CustomerScreens.swift
//  WalkAndTakeKit
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
    public let profile: ProfileModel
    private let dependencies: CustomerDependencies
    private let developerDestination: ((ProfileRoute) -> AnyView)?

    /// - Parameter developerDestination: DEBUG tools (time travel, seed map) the app supplies;
    ///   nil hides Profile's Developer section.
    public init(
        dependencies: CustomerDependencies,
        navigation: CustomerNavigation,
        developerDestination: ((ProfileRoute) -> AnyView)? = nil
    ) {
        self.dependencies = dependencies
        self.navigation = navigation
        self.developerDestination = developerDestination
        discover = DiscoverModel(dependencies: dependencies)
        orders = OrdersModel(dependencies: dependencies)
        favorites = FavoritesModel(dependencies: dependencies)
        profile = ProfileModel(dependencies: dependencies, navigation: navigation)
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

    public func profileTab() -> some View {
        ProfileView(model: profile, navigation: navigation, developerDestination: developerDestination)
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
            ) { [dependencies] request in
                RateOrderView(
                    model: RateOrderModel(
                        reservationID: request.reservationID, initialStars: request.stars, dependencies: dependencies))
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
