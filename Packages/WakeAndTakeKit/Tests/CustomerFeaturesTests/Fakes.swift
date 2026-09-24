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
        var nextReserveError: (any Error)?
        var codes = 0
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

    /// Makes the next `reserve` throw `error` instead of reserving.
    func failNextReserve(with error: any Error) { state.withLock { $0.nextReserveError = error } }

    var reservationCount: Int { state.withLock { $0.reservations.count } }

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
    func reserve(offerID: String, quantity: Int, at now: Date) async throws -> Reservation {
        let reservation = try state.withLock { s -> Reservation in
            if let error = s.nextReserveError {
                s.nextReserveError = nil
                throw error
            }
            guard let index = s.offers.firstIndex(where: { $0.id == offerID }),
                let restaurant = s.restaurants.first(where: { $0.id == s.offers[index].restaurantID })
            else { throw ReservationError.offerNoLongerExists }
            try ReservationPolicy.validateReservation(
                of: s.offers[index], quantity: quantity, at: now, calendar: NYCalendar.calendar)
            s.offers[index].quantityReserved += quantity
            s.codes += 1
            let reservation = Reservation(
                id: UUID(), confirmationCode: "AB2\(s.codes)", quantity: quantity,
                snapshot: OfferSnapshot(offer: s.offers[index], restaurant: restaurant), reservedAt: now)
            s.reservations.append(reservation)
            return reservation
        }
        broadcaster.send(.stockChanged(offerID: offerID))
        broadcaster.send(.reservationsChanged)
        return reservation
    }
    func changeQuantity(reservationID: UUID, to quantity: Int, at now: Date) async throws -> Reservation {
        try mutate(reservationID) { s, r, offerIndex in
            let left = offerIndex.map { s.offers[$0].quantityLeft } ?? 0
            try ReservationPolicy.validateChange(of: r, to: quantity, offerQuantityLeft: left, at: now)
            if let i = offerIndex { s.offers[i].quantityReserved += quantity - r.quantity }
            r.quantity = quantity
        }
    }
    func cancel(reservationID: UUID, reason: CancelReason?, at now: Date) async throws -> Reservation {
        try mutate(reservationID) { s, r, offerIndex in
            try ReservationPolicy.validateCancel(of: r, at: now)
            if let i = offerIndex { s.offers[i].quantityReserved -= r.quantity }
            r.cancelledAt = now
            r.cancelReason = reason
        }
    }
    func markCollected(reservationID: UUID, at now: Date) async throws -> Reservation {
        try mutate(reservationID) { _, r, _ in
            try ReservationPolicy.validateCollect(of: r, at: now)
            r.collectedAt = now
        }
    }

    /// Adds a reservation directly (as if made earlier) and takes its stock.
    @discardableResult
    func add(_ reservation: Reservation) -> Reservation {
        state.withLock { s in
            s.reservations.insert(reservation, at: 0)
            if let i = s.offers.firstIndex(where: { $0.id == reservation.snapshot.offerID }) {
                s.offers[i].quantityReserved += reservation.quantity
            }
        }
        broadcaster.send(.reservationsChanged)
        return reservation
    }

    func offerLeft(_ id: String) -> Int? { state.withLock { s in s.offers.first { $0.id == id }?.quantityLeft } }

    private func mutate(
        _ id: UUID, _ change: (inout State, inout Reservation, Int?) throws -> Void
    ) throws -> Reservation {
        let updated = try state.withLock { s -> Reservation in
            if let error = s.nextReserveError {
                s.nextReserveError = nil
                throw error
            }
            guard let index = s.reservations.firstIndex(where: { $0.id == id }) else {
                throw ReservationError.reservationNotFound
            }
            var reservation = s.reservations[index]
            let offerIndex = s.offers.firstIndex { $0.id == reservation.snapshot.offerID }
            try change(&s, &reservation, offerIndex)
            s.reservations[index] = reservation
            return reservation
        }
        broadcaster.send(.reservationsChanged)
        return updated
    }
    func reservations() async throws -> [Reservation] { try read(\.reservations) }
    func reservation(id: UUID) async throws -> Reservation? { try read { $0.reservations.first { $0.id == id } } }

    // ReviewRepository
    func submitReview(_ review: Review, for reservationID: UUID, at now: Date) async throws -> Restaurant? {
        let restaurant = try state.withLock { s -> Restaurant? in
            guard let index = s.reservations.firstIndex(where: { $0.id == reservationID }) else {
                throw ReviewError.notEligible
            }
            try ReviewPolicy.validate(review, for: s.reservations[index], at: now)
            s.reservations[index].review = review
            guard let r = s.restaurants.firstIndex(where: { $0.id == s.reservations[index].snapshot.restaurantID })
            else { return nil }
            let folded = ReviewPolicy.foldedRating(
                rating: s.restaurants[r].rating, reviewCount: s.restaurants[r].reviewCount, adding: review.overall)
            s.restaurants[r].rating = folded.rating
            s.restaurants[r].reviewCount = folded.reviewCount
            return s.restaurants[r]
        }
        broadcaster.send(.reservationsChanged)
        return restaurant
    }

    /// Clears reservations (what a reset does to the marketplace, for these tests).
    func clearReservations() {
        state.withLock { $0.reservations = [] }
        broadcaster.send(.reset)
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

    func wipe() {
        state.withLock { $0 = State() }
        broadcaster.send(.reset)
    }
}

/// Scripted permission answer; records previews.
nonisolated final class FakeNotifications: NotificationScheduler, Sendable {
    private let granted = Mutex(true)
    private let previews = Mutex<[String]>([])

    func setPermission(_ allowed: Bool) { granted.withLock { $0 = allowed } }
    var previewOfferIDs: [String] { previews.withLock { $0 } }

    func requestPermission() async -> Bool { granted.withLock { $0 } }
    func schedule(_ alerts: [OfferAlert], now: Date) async {}
    func replaceAll(with alerts: [OfferAlert], now: Date) async {}
    func cancel(offerIDs: [String]) async {}
    func cancelAll() async {}
    func sendPreview(_ alert: OfferAlert) async { previews.withLock { $0.append(alert.offerID) } }
}

/// Wipes the fakes the way DemoDataResetter wipes the stores.
nonisolated final class FakeResetter: DemoDataResetting, Sendable {
    private let calls = Mutex(0)
    private let fail = Mutex(false)
    let marketplace: FakeMarketplace
    let userData: FakeUserData

    init(marketplace: FakeMarketplace, userData: FakeUserData) {
        self.marketplace = marketplace
        self.userData = userData
    }

    var resetCount: Int { calls.withLock { $0 } }
    func failNext() { fail.withLock { $0 = true } }

    func resetAll() async throws {
        if fail.withLock({ f in
            defer { f = false }
            return f
        }) {
            throw TestError()
        }
        calls.withLock { $0 += 1 }
        marketplace.clearReservations()
        userData.wipe()
    }
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
        mapBrowse: Bool = true, favorites: Bool = true, notifications: Bool = true, dietaryFilters: Bool = true,
        manageOrder: Bool = true, reviews: Bool = true, impact: Bool = true, commute: Bool = false
    ) -> FeatureFlags {
        FeatureFlags(
            mapBrowse: mapBrowse, favorites: favorites, notifications: notifications, dietaryFilters: dietaryFilters,
            manageOrder: manageOrder, reviews: reviews, impact: impact, commute: commute)
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

    /// A reservation for `offer` as it looked when reserved.
    static func reservation(
        for offer: Offer, quantity: Int = 1, reservedAt: Date = sep(24, 6), collectedAt: Date? = nil,
        cancelledAt: Date? = nil, review: Review? = nil
    ) -> Reservation {
        Reservation(
            id: UUID(), confirmationCode: "QW3E", quantity: quantity,
            snapshot: OfferSnapshot(offer: offer, restaurant: restaurants.first { $0.id == offer.restaurantID }!),
            reservedAt: reservedAt, collectedAt: collectedAt, cancelledAt: cancelledAt, review: review)
    }

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
    let notifications = FakeNotifications()
    let resetter: FakeResetter
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
        resetter = FakeResetter(marketplace: marketplace, userData: userData)
        dependencies = CustomerDependencies(
            offers: marketplace, reservations: marketplace, reviews: marketplace, favorites: userData,
            preferences: userData, location: FakeLocation(result: location), notifications: notifications,
            resetter: resetter, clock: clock, flags: flags)
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
