//
//  Seed.swift
//  WalkAndTakeKit
//

import Domain
import Foundation

/// Validated seed data. Templates are read from the bundled JSON on every launch
/// rather than persisted: they're immutable config, and the bundle is their source of truth.
public struct Seed: Sendable {
    public var version: SeedVersion
    public var restaurants: [Restaurant]
    public var templates: [OfferTemplate]

    public init(version: SeedVersion, restaurants: [Restaurant], templates: [OfferTemplate]) {
        self.version = version
        self.restaurants = restaurants
        self.templates = templates
    }
}
