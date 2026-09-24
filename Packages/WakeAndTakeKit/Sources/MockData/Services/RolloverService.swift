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
    private let alertsEnabled: Bool

    /// - Parameter alertsEnabled: The notifications (and favorites) flags; when off, no alerts are scheduled.
    public init(
        marketplace: MarketplaceStore,
        userData: UserDataStore,
        notifications: any NotificationScheduler,
        clock: any Clock,
        alertsEnabled: Bool = true
    ) {
        self.marketplace = marketplace
        self.userData = userData
        self.notifications = notifications
        self.clock = clock
        self.alertsEnabled = alertsEnabled
    }

    /// Safe to call any number of times; a no-op unless the New York day or seed changed.
    @discardableResult
    public func run() async throws -> Bool {
        let now = clock.now
        guard try await marketplace.rolloverIfNeeded(at: now) else { return false }
        try await rescheduleAlerts(at: now)
        return true
    }

    /// Keeps pending alerts matching favorites and stock for as long as it runs: a bag that
    /// sells out loses its alert, a restocked one gets it back, and toggling alerts applies.
    public func syncAlerts() async {
        let stock = marketplace.changes()
        let favorites = userData.changes()
        try? await rescheduleAlerts(at: clock.now)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await change in stock {
                    if case .stockChanged = change { try? await rescheduleAlerts(at: clock.now) }
                }
            }
            group.addTask {
                for await change in favorites where change == .favoritesChanged || change == .reset {
                    try? await rescheduleAlerts(at: clock.now)
                }
            }
        }
    }

    /// Replaces every pending drop alert with the current plan.
    public func rescheduleAlerts(at now: Date) async throws {
        guard alertsEnabled else {
            await notifications.replaceAll(with: [], now: now)
            return
        }
        let alerts = NotificationPlan.alerts(
            for: try await userData.favorites(),
            offers: try await marketplace.offersNotYetOpen(at: now),
            restaurants: try await marketplace.restaurants(),
            now: now
        )
        await notifications.replaceAll(with: alerts, now: now)
    }
}
