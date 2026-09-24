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
    private let dependencies: CustomerDependencies

    public init(dependencies: CustomerDependencies, navigation: CustomerNavigation) {
        self.dependencies = dependencies
        self.navigation = navigation
        discover = DiscoverModel(dependencies: dependencies)
    }

    public func discoverTab() -> some View {
        DiscoverView(model: discover, navigation: navigation) { [unowned self] route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func destination(for route: DiscoverRoute) -> some View {
        switch route {
        case .offer(let id):
            OfferDetailPlaceholderView(offerID: id)
        }
    }
}
