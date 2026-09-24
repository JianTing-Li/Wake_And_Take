//
//  AppDependencies.swift
//  WakeAndTake
//
//  The composition root: the only place that knows concrete stores exist.
//  Features receive Domain repository protocols and a Clock from here.
//

import CustomerFeatures
import Domain
import Foundation
import MockData
import OSLog
import Platform
import SwiftData

@MainActor
final class AppDependencies {
    let role: UserRole = .customer
    let flags: FeatureFlags
    let clock: any Clock
    #if DEBUG
        /// The same clock as `clock`, exposed for time travel.
        let debugClock: AdjustableClock
    #endif

    let marketplace: MarketplaceStore
    let userData: UserDataStore
    let location: any LocationProvider
    let notifications: any NotificationScheduler
    let notificationDelegate = NotificationBannerDelegate()
    let rollover: RolloverService
    let resetter: any DemoDataResetting
    let navigation = CustomerNavigation()
    let screens: CustomerScreens

    // Repositories, as the protocols features depend on.
    var offers: any OfferRepository { marketplace }
    var reservations: any ReservationRepository { marketplace }
    var reviews: any ReviewRepository { marketplace }
    var favorites: any FavoritesRepository { userData }
    var preferences: any PreferencesRepository { userData }

    private static let log = Logger(subsystem: "org.pursuit.Wake-And-Take", category: "App")

    init() {
        flags = .default
        #if DEBUG
            debugClock = AdjustableClock()
            clock = debugClock
        #else
            clock = LiveClock()
        #endif

        let seed: Seed
        let container: ModelContainer
        do {
            seed = try SeedLoader.loadBundled()
            container = try ModelContainerFactory.makePersistent()
        } catch {
            fatalError("Wake&Take can't start without its seed data and store: \(error)")
        }

        marketplace = MarketplaceStore(modelContainer: container, seed: seed)
        userData = UserDataStore(modelContainer: container)
        location = DeviceLocationProvider(source: CoreLocationSource())
        notifications = LiveNotificationScheduler()
        rollover = RolloverService(
            marketplace: marketplace, userData: userData, notifications: notifications, clock: clock,
            alertsEnabled: flags.alertsEnabled)
        resetter = DemoDataResetter(
            marketplace: marketplace, userData: userData, notifications: notifications, clock: clock)
        screens = CustomerScreens(
            dependencies: CustomerDependencies(
                offers: marketplace, reservations: marketplace, reviews: marketplace, favorites: userData,
                preferences: userData, location: location, notifications: notifications, resetter: resetter,
                clock: clock,
                flags: flags),
            navigation: navigation)
    }

    /// Rolls the marketplace over if the New York day (or seed) changed. Safe to call often.
    func runRollover(reason: String) async {
        do {
            if try await rollover.run() {
                Self.log.info("Rolled over (\(reason, privacy: .public))")
            }
        } catch {
            Self.log.error("Rollover failed (\(reason, privacy: .public)): \(error)")
        }
    }
}
