//
//  FeatureFlags+Default.swift
//  WalkAndTake
//
//  Compile-time feature switches. A flag that's off hides UI entry points only.
//

import Domain

extension FeatureFlags {
    static let `default` = FeatureFlags(
        mapBrowse: true,
        favorites: true,
        notifications: true,
        dietaryFilters: true,
        manageOrder: true,
        reviews: true,
        impact: true,
        commute: false
    )
}
