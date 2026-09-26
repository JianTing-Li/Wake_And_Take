//
//  FavoritesModel.swift
//  WalkAndTakeKit
//
//  User Journey 3: a customer saves favorite stores and gets alerted
//  when they have bags, so they never miss a deal.
//

import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class FavoritesModel {
    public enum State: Equatable {
        case loading, loaded, empty
        case failed(String)
    }

    public struct Row: Identifiable, Hashable, Sendable {
        public enum Status: Hashable, Sendable {
            /// Open for pickup now: "3 left · Ends in 20 min".
            case availableNow(String)
            /// Reservable, not open yet: "Opens tomorrow at 7:30 AM".
            case upcoming(String)
            case none
        }

        public var id: String { restaurantID }
        public let restaurantID: String
        public let name: String
        public let category: FoodCategory?
        public let status: Status
        public let alertsOn: Bool
        /// The bag a tap opens: open now, or opening soonest.
        public let nextOfferID: String?
    }

    public private(set) var state: State = .loading
    /// Notification permission was refused; the view offers Settings.
    public var notificationsBlocked = false
    public private(set) var previewSent = false

    private var favorites: [FavoriteRestaurant] = []
    private var offers: [Offer] = []
    private var restaurants: [String: Restaurant] = [:]
    private var now: Date
    private let dependencies: CustomerDependencies
    private let previewResetDelay: Duration

    public init(dependencies: CustomerDependencies, previewResetDelay: Duration = .seconds(6)) {
        self.dependencies = dependencies
        self.previewResetDelay = previewResetDelay
        now = dependencies.clock.now
    }

    public var flags: FeatureFlags { dependencies.flags }
    /// Bells and the preview need both the favorites and notifications flags.
    public var showsAlerts: Bool { flags.alertsEnabled }

    // MARK: - Lifecycle

    public func run() async {
        await load()
        let offerChanges = dependencies.offers.changes()
        let userChanges = dependencies.favorites.changes()
        let clockChanges = dependencies.clock.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in offerChanges { await self.load() } }
            group.addTask { for await _ in userChanges { await self.load() } }
            group.addTask { for await _ in clockChanges { await self.load() } }
            group.addTask {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    await self.load()
                }
            }
        }
    }

    public func load() async {
        let now = dependencies.clock.now
        do {
            async let favorites = dependencies.favorites.favorites()
            async let offers = dependencies.offers.offers(visibleAt: now)
            async let restaurants = dependencies.offers.restaurants()
            self.favorites = try await favorites
            self.offers = try await offers
            self.restaurants = Dictionary(uniqueKeysWithValues: try await restaurants.map { ($0.id, $0) })
            self.now = now
            state = self.favorites.isEmpty ? .empty : .loaded
        } catch {
            if state == .loading { state = .failed("Couldn't load your favorites. Please try again.") }
        }
    }

    // MARK: - Actions

    public func remove(_ restaurantIDs: [String]) async {
        for id in restaurantIDs {
            try? await dependencies.favorites.setFavorite(false, restaurantID: id)
        }
        await load()
    }

    /// Turns alerts on (asking for permission first) or off for one restaurant.
    public func toggleAlerts(for restaurantID: String) async {
        guard showsAlerts else { return }
        let turnOn = !(favorites.first { $0.restaurantID == restaurantID }?.alertsEnabled ?? false)
        if turnOn, await !dependencies.notifications.requestPermission() {
            notificationsBlocked = true
            return
        }
        try? await dependencies.favorites.setAlerts(turnOn, restaurantID: restaurantID)
        await load()
    }

    /// Sends a sample alert in a few seconds so the customer can see one.
    public func sendPreview() async {
        guard showsAlerts, let alert = previewAlert else { return }
        guard await dependencies.notifications.requestPermission() else {
            notificationsBlocked = true
            return
        }
        await dependencies.notifications.sendPreview(alert)
        previewSent = true
        try? await Task.sleep(for: previewResetDelay)
        previewSent = false
    }

    // MARK: - Output

    /// Open now first, then opening later, then none; alphabetical within each.
    public var rows: [Row] {
        favorites.compactMap { favorite -> Row? in
            guard let restaurant = restaurants[favorite.restaurantID] else { return nil }
            let theirs = offers.filter { $0.restaurantID == restaurant.id }
            let next =
                theirs
                .filter { OfferAvailability.status(of: $0, at: now).isReservable }
                .min { $0.pickupWindow.start < $1.pickupWindow.start }
            return Row(
                restaurantID: restaurant.id,
                name: restaurant.name,
                category: (next ?? theirs.first)?.category,
                status: status(of: next),
                alertsOn: favorite.alertsEnabled,
                nextOfferID: next?.id
            )
        }
        .sorted { (rank($0.status), $0.name) < (rank($1.status), $1.name) }
    }

    /// A favorite's bag if possible, otherwise any visible bag.
    var previewAlert: OfferAlert? {
        let favoriteIDs = Set(favorites.map(\.restaurantID))
        let offer = offers.first { favoriteIDs.contains($0.restaurantID) } ?? offers.first
        guard let offer, let restaurant = restaurants[offer.restaurantID] else { return nil }
        return OfferAlert(offer: offer, restaurantName: restaurant.name)
    }

    private func status(of offer: Offer?) -> Row.Status {
        guard let offer else { return .none }
        let countdown = PickupDayFormatter.countdown(offer.pickupWindow, now: now, calendar: NYCalendar.calendar)
        return offer.pickupWindow.hasStarted(at: now)
            ? .availableNow("\(offer.quantityLeft) left · \(countdown)") : .upcoming(countdown)
    }

    private func rank(_ status: Row.Status) -> Int {
        switch status {
        case .availableNow: 0
        case .upcoming: 1
        case .none: 2
        }
    }
}
