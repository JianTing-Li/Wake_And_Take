//
//  ModelContainerFactory.swift
//  WalkAndTakeKit
//

import Foundation
import SwiftData

/// Builds the one `ModelContainer` both stores share.
public enum ModelContainerFactory {
    static let schema = Schema([
        RestaurantEntity.self,
        OfferEntity.self,
        ReservationEntity.self,
        FavoriteEntity.self,
        PreferencesEntity.self,
        CommuteProfileEntity.self,
        MetadataEntity.self,
    ])

    /// The app's on-disk store.
    public static func makePersistent() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: ModelConfiguration("WalkAndTake", schema: schema))
    }

    /// A private in-memory store for previews, tests and UI tests.
    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// An on-disk store at a specific location (tests of persistence across launches).
    public static func make(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
    }
}
