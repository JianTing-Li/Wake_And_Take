//
//  SeedVersion.swift
//  WalkAndTakeKit
//

import Foundation

/// Both files' `schemaVersion`s. A change triggers a reseed of restaurants and future offers.
public struct SeedVersion: Hashable, Sendable {
    public var restaurants: Int
    public var templates: Int

    public init(restaurants: Int, templates: Int) {
        self.restaurants = restaurants
        self.templates = templates
    }

    /// Stored in metadata, e.g. "r2-t2".
    public var rawValue: String { "r\(restaurants)-t\(templates)" }
}
