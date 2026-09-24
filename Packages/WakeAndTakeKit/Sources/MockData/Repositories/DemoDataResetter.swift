//
//  DemoDataResetter.swift
//  WakeAndTakeKit
//

import Domain
import Foundation
import Platform

/// Wipes both stores, reseeds and rolls over the marketplace, and cancels pending alerts.
/// Navigation back to each tab's root is the app's job when it sees `.reset`.
public struct DemoDataResetter: DemoDataResetting {
    private let marketplace: MarketplaceStore
    private let userData: UserDataStore
    private let notifications: any NotificationScheduler
    private let clock: any Clock

    public init(
        marketplace: MarketplaceStore,
        userData: UserDataStore,
        notifications: any NotificationScheduler,
        clock: any Clock
    ) {
        self.marketplace = marketplace
        self.userData = userData
        self.notifications = notifications
        self.clock = clock
    }

    public func resetAll() async throws {
        try await userData.deleteAll()
        try await marketplace.resetDemoData(at: clock.now)
        await notifications.cancelAll()
    }
}
