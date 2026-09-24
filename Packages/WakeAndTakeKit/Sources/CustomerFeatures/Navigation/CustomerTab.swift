//
//  CustomerTab.swift
//  WakeAndTakeKit
//

import Domain

public enum CustomerTab: Hashable, CaseIterable, Sendable {
    case discover, orders, favorites, profile

    /// Tabs shown for these flags; Favorites disappears when its flag is off.
    public static func visible(with flags: FeatureFlags) -> [CustomerTab] {
        allCases.filter { $0 != .favorites || flags.favorites }
    }
}
