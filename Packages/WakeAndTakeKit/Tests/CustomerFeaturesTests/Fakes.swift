//
//  Fakes.swift
//  CustomerFeaturesTests
//
//  In-memory repositories, a scripted location, and fixture data for view-model tests.
//

import Domain
import Foundation
import Platform
import Synchronization

@testable import CustomerFeatures

nonisolated struct TestError: Error {}

/// Marketplace fake: applies the real visibility rule and emits changes on mutation.
nonisolated final class FakeMarketplace: OfferRepository, ReservationRepository, ReviewRepository, Sendable {
    private struct State {
        var offers: [Offer] = []
        var restaurants: [Restaurant] = []
        var reservations: [Reservation] = []
        var failReads = false
    }

    private let state: Mutex<State>
    private let broadcaster = Broadcaster<MarketplaceChange>()

    init(offers: [Offer] = [], restaurants: [Restaurant] = Fixture.restaurants) {
        state = Mutex(State(offers: offers, restaurants: restaurants))
    }

    func set(offers: [Offer]) {
        state.withLock { $0.offers = offers }
        broadcaster.send(.rolledOver)
    }

    func failReads(_ fail: Bool) { state.withLock { $0.failReads = fail } }

    private func read<T>(_ body: (State) -> T) throws -> T {
        try state.withLock { s in
            if s.failReads { throw TestError() }
            return body(s)
        }
    }

    // OfferRepository
    func offers(visibleAt now: Date) async throws -> [Offer] {
        try read { $0.offers.filter { OfferVisibility.isVisible($0, at: now, calendar: NYCalendar.calendar) } }
    }
    func offer(id: String) async throws -> Offer? { try read { $0.offers.first { $0.id == id } } }
    func restaurants() async throws -> [Restaurant] { try read(\.restaurants) }
    func restaurant(id: String) async throws -> Restaurant? { try read { $0.restaurants.first { $0.id == id } } }
    func changes() -> AsyncStream<MarketplaceChange> { broadcaster.stream() }

    // ReservationRepository (filled in by later sub-phases)
    func reserve(offerID: String, quantity: Int, at now: Date) async throws -> Reservation { throw TestError() }
    func changeQuantity(reservationID: UUID, to quantity: Int, at now: Date) async throws -> Reservation {
        throw TestError()
    }
    func cancel(reservationID: UUID, reason: CancelReason?, at now: Date) async throws -> Reservation {
        throw TestError()
    }
    func markCollected(reservationID: UUID, at now: Date) async throws -> Reservation { throw TestError() }
    func reservations() async throws -> [Reservation] { try read(\.reservations) }
    func reservation(id: UUID) async throws -> Reservation? { try read { $0.reservations.first { $0.id == id } } }

    // ReviewRepository
    func submitReview(_ review: Review, for reservationID: UUID, at now: Date) async throws -> Restaurant? {
        throw TestError()
    }
}

/// Favorites + preferences fake.
nonisolated final class FakeUserData: FavoritesRepository, PreferencesRepository, Sendable {
    private struct State {
        var favorites: [FavoriteRestaurant] = []
        var preferences = UserPreferences()
        var commute = CommuteProfile()
    }

    private let state: Mutex<State>
    private let broadcaster = Broadcaster<UserDataChange>()

    init(preferences: UserPreferences = UserPreferences(), favorites: [FavoriteRestaurant] = []) {
        state = Mutex(State(favorites: favorites, preferences: preferences))
    }

    var favoriteIDs: [String] { state.withLock { $0.favorites.map(\.restaurantID) } }

    func favorites() async throws -> [FavoriteRestaurant] { state.withLock { $0.favorites } }
    func setFavorite(_ isFavorite: Bool, restaurantID: String) async throws {
        state.withLock { s in
            s.favorites.removeAll { $0.restaurantID == restaurantID }
            if isFavorite { s.favorites.append(FavoriteRestaurant(restaurantID: restaurantID, alertsEnabled: false)) }
        }
        broadcaster.send(.favoritesChanged)
    }
    func setAlerts(_ enabled: Bool, restaurantID: String) async throws {
        state.withLock { s in
            s.favorites.removeAll { $0.restaurantID == restaurantID }
            s.favorites.append(FavoriteRestaurant(restaurantID: restaurantID, alertsEnabled: enabled))
        }
        broadcaster.send(.favoritesChanged)
    }
    func preferences() async throws -> UserPreferences { state.withLock { $0.preferences } }
    func updatePreferences(_ preferences: UserPreferences) async throws {
        state.withLock { $0.preferences = preferences }
        broadcaster.send(.preferencesChanged)
    }
    func commuteProfile() async throws -> CommuteProfile { state.withLock { $0.commute } }
    func updateCommuteProfile(_ profile: CommuteProfile) async throws {
        state.withLock { $0.commute = profile }
        broadcaster.send(.commuteChanged)
    }
    func changes() -> AsyncStream<UserDataChange> { broadcaster.stream() }
}

nonisolated struct FakeLocation: LocationProvider {
    var result: ResolvedLocation
    func resolve() async -> ResolvedLocation { result }
}

nonisolated enum Fixture {
    static let licCenter = ServiceArea.longIslandCity.center

    /// A New York time in September 2026 (Thu the 24th is "today").
    static func sep(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        NYCalendar.date(on: DayKey(rawValue: String(format: "2026-09-%02d", day)), hour: hour, minute: minute)!
    }

    static func flags(
        mapBrowse: Bool = true, favorites: Bool = true, dietaryFilters: Bool = true, reviews: Bool = true,
        commute: Bool = false
    ) -> FeatureFlags {
        FeatureFlags(
            mapBrowse: mapBrowse, favorites: favorites, notifications: true, dietaryFilters: dietaryFilters,
            manageOrder: true, reviews: reviews, impact: true, commute: commute)
    }

    static func restaurant(_ id: String, name: String, lat: Double, lng: Double) -> Restaurant {
        Restaurant(
            id: id, name: name, kind: .cafe,
            address: .init(
                street: "Vernon Blvd", crossStreet: "48th Ave", neighborhood: "Long Island City",
                borough: "Queens", zip: "11101"),
            coordinate: Coordinate(latitude: lat, longitude: lng), pickupInstructions: "Ask at the counter.",
            rating: 4.5, reviewCount: 100)
    }

    /// ~0.24 mi, ~0.54 mi, and ~2.4 mi (Midtown) from the LIC center.
    static let restaurants = [
        restaurant("near", name: "Near Café", lat: 40.7443, lng: -73.9532),
        restaurant("mid", name: "Mid Deli", lat: 40.7497, lng: -73.9390),
        restaurant("far", name: "Far Bistro", lat: 40.7580, lng: -73.9855),
    ]

    static func offer(
        _ template: String, restaurant: String = "near", day: Int = 24, start: (Int, Int), end: (Int, Int),
        category: FoodCategory = .breakfast, price: Int = 500, total: Int = 5, reserved: Int = 0,
        dietary: Set<DietaryTag> = []
    ) -> Offer {
        let key = DayKey(rawValue: String(format: "2026-09-%02d", day))
        return Offer(
            id: Offer.makeID(templateID: template, day: key), templateID: template, restaurantID: restaurant,
            name: "\(template) bag", category: category, summary: "Might include things.", dietary: dietary,
            price: Money(cents: price), estimatedValue: Money(cents: price * 3), quantityTotal: total,
            quantityReserved: reserved,
            pickupWindow: PickupWindow(
                start: NYCalendar.date(on: key, hour: start.0, minute: start.1)!,
                end: NYCalendar.date(on: key, hour: end.0, minute: end.1)!))
    }
}

@MainActor
struct Harness {
    let marketplace: FakeMarketplace
    let userData: FakeUserData
    let clock: AdjustableClock
    let dependencies: CustomerDependencies

    init(
        now: Date,
        offers: [Offer],
        preferences: UserPreferences = UserPreferences(),
        favorites: [FavoriteRestaurant] = [],
        location: ResolvedLocation = ResolvedLocation(coordinate: Fixture.licCenter, source: .device),
        flags: FeatureFlags = Fixture.flags()
    ) {
        marketplace = FakeMarketplace(offers: offers)
        userData = FakeUserData(preferences: preferences, favorites: favorites)
        clock = AdjustableClock(fixedAt: now)
        dependencies = CustomerDependencies(
            offers: marketplace, reservations: marketplace, reviews: marketplace, favorites: userData,
            preferences: userData, location: FakeLocation(result: location), clock: clock, flags: flags)
    }
}

/// Polls until `condition` holds (for stream-driven updates), up to ~2 s.
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
