//
//  Routes.swift
//  WakeAndTakeKit
//
//  Typed navigation paths per tab, so the app can pop or deep-link any tab.
//

import Foundation

public enum DiscoverRoute: Hashable, Sendable {
    case offer(id: String)
}

public enum OrdersRoute: Hashable, Sendable {
    case pickup(reservationID: UUID)
    case manageOrder(reservationID: UUID)
}

public enum FavoritesRoute: Hashable, Sendable {
    case offer(id: String)
}

public enum ProfileRoute: Hashable, Sendable {
    /// DEBUG developer tools; the app supplies these screens.
    case timeTravel
    case seedMap
}
