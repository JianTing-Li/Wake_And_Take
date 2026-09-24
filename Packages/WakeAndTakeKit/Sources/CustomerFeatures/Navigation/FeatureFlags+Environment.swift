//
//  FeatureFlags+Environment.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

extension EnvironmentValues {
    /// Set by the app from `FeatureFlags.default`. The fallback (everything on) only
    /// applies to previews that don't inject flags.
    @Entry public var featureFlags = FeatureFlags(
        mapBrowse: true, favorites: true, notifications: true, dietaryFilters: true,
        manageOrder: true, reviews: true, impact: true, commute: true
    )
}
