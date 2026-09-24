//
//  UserDataStore.swift
//  WakeAndTakeKit
//
//  Owns favorites (by restaurant ID), alert settings, preferences and the commute.
//

import Domain
import Foundation
import Platform
import SwiftData

public actor UserDataStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let broadcaster = Broadcaster<UserDataChange>()

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    public nonisolated func changes() -> AsyncStream<UserDataChange> {
        broadcaster.stream()
    }

    // MARK: - Favorites

    public func favorites() throws -> [FavoriteRestaurant] {
        try modelContext.fetch(FetchDescriptor<FavoriteEntity>(sortBy: [SortDescriptor(\.restaurantID)]))
            .map(\.domain)
    }

    public func setFavorite(_ isFavorite: Bool, restaurantID: String) throws {
        let existing = try favorite(restaurantID)
        switch (isFavorite, existing) {
        case (true, nil): modelContext.insert(FavoriteEntity(restaurantID: restaurantID, alertsEnabled: false))
        case (false, let entity?): modelContext.delete(entity)
        default: return
        }
        try save(.favoritesChanged)
    }

    public func setAlerts(_ enabled: Bool, restaurantID: String) throws {
        if let entity = try favorite(restaurantID) {
            guard entity.alertsEnabled != enabled else { return }
            entity.alertsEnabled = enabled
        } else if enabled {
            modelContext.insert(FavoriteEntity(restaurantID: restaurantID, alertsEnabled: true))
        } else {
            return
        }
        try save(.favoritesChanged)
    }

    // MARK: - Preferences

    public func preferences() throws -> UserPreferences {
        try modelContext.fetch(FetchDescriptor<PreferencesEntity>()).first?.domain ?? UserPreferences()
    }

    public func updatePreferences(_ preferences: UserPreferences) throws {
        if let entity = try modelContext.fetch(FetchDescriptor<PreferencesEntity>()).first {
            entity.apply(preferences)
        } else {
            modelContext.insert(PreferencesEntity(preferences))
        }
        try save(.preferencesChanged)
    }

    public func commuteProfile() throws -> CommuteProfile {
        try modelContext.fetch(FetchDescriptor<CommuteProfileEntity>()).first?.domain ?? CommuteProfile()
    }

    public func updateCommuteProfile(_ profile: CommuteProfile) throws {
        if let entity = try modelContext.fetch(FetchDescriptor<CommuteProfileEntity>()).first {
            entity.apply(profile)
        } else {
            modelContext.insert(CommuteProfileEntity(profile))
        }
        try save(.commuteChanged)
    }

    // MARK: - Reset

    public func deleteAll() throws {
        try modelContext.fetch(FetchDescriptor<FavoriteEntity>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<PreferencesEntity>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<CommuteProfileEntity>()).forEach(modelContext.delete)
        try save(.reset)
    }

    // MARK: - Helpers

    private func favorite(_ restaurantID: String) throws -> FavoriteEntity? {
        try modelContext.fetch(
            FetchDescriptor<FavoriteEntity>(predicate: #Predicate { $0.restaurantID == restaurantID })
        )
        .first
    }

    private func save(_ change: UserDataChange) throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        broadcaster.send(change)
    }
}
