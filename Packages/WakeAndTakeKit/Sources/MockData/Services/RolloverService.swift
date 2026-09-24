//
//  RolloverService.swift
//  WakeAndTakeKit
//
//  What the app runs on launch, on becoming active, on significant time changes,
//  and when the debug clock moves: roll the marketplace over and, if anything
//  changed, rebuild pending alerts for favorite restaurants.
//

import Domain
import Foundation
import Platform

public struct RolloverService: Sendable {
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

    /// Safe to call any number of times; a no-op unless the New York day or seed changed.
    @discardableResult
    public func run() async throws -> Bool {
        let now = clock.now
        guard try await marketplace.rolloverIfNeeded(at: now) else { return false }
        try await rescheduleAlerts(at: now)
        return true
    }

    /// Replaces every pending drop alert with the current plan.
    public func rescheduleAlerts(at now: Date) async throws {
        let alerts = NotificationPlan.alerts(
            for: try await userData.favorites(),
            offers: try await marketplace.offersNotYetOpen(at: now),
            restaurants: try await marketplace.restaurants(),
            now: now
        )
        await notifications.replaceAll(with: alerts, now: now)
    }
}
