//
//  DiscoverModel.swift
//  WakeAndTakeKit
//
//  User Journey 1: a customer finds affordable surplus food nearby
//  and reserves it before the pickup window ends.
//

import DesignSystem
import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class DiscoverModel {
    public enum State: Equatable {
        case loading, loaded, empty
        case failed(String)
    }

    public private(set) var state: State = .loading
    public var category: FoodCategory?
    public var sort: DiscoverSortOrder = .endingSoon
    public var mode: DiscoverMode = .list
    public private(set) var now: Date

    /// The map mode's model; kept in sync with the same catalog.
    public let map: MapBrowseModel

    private(set) var catalog: OfferCatalog
    private let dependencies: CustomerDependencies

    public init(dependencies: CustomerDependencies) {
        let now = dependencies.clock.now
        let catalog = OfferCatalog(flags: dependencies.flags)
        self.dependencies = dependencies
        self.now = now
        self.catalog = catalog
        map = MapBrowseModel(catalog: catalog, now: now)
    }

    public var flags: FeatureFlags { dependencies.flags }

    // MARK: - Lifecycle

    /// Loads, then keeps the screen current until the view goes away.
    public func run() async {
        await load()
        let offers = dependencies.offers.changes()
        let userData = dependencies.favorites.changes()
        let clockChanges = dependencies.clock.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.resolveLocation() }
            group.addTask { for await _ in offers { await self.load() } }
            group.addTask { for await _ in userData { await self.load() } }
            group.addTask { for await _ in clockChanges { await self.load() } }
            group.addTask {
                // Countdowns, and tomorrow's offers appearing at 20:00.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    await self.load()
                }
            }
        }
    }

    /// Fetches everything; only the first load shows the spinner.
    public func load() async {
        let now = dependencies.clock.now
        do {
            async let offers = dependencies.offers.offers(visibleAt: now)
            async let restaurants = dependencies.offers.restaurants()
            async let favorites = dependencies.favorites.favorites()
            async let preferences = dependencies.preferences.preferences()
            async let commute = dependencies.preferences.commuteProfile()

            var catalog = self.catalog
            catalog.offers = try await offers
            catalog.restaurants = Dictionary(uniqueKeysWithValues: try await restaurants.map { ($0.id, $0) })
            catalog.favoriteIDs = Set(try await favorites.map(\.restaurantID))
            catalog.preferences = try await preferences
            catalog.commute = try await commute
            apply(catalog, now: now)
        } catch {
            if state == .loading { state = .failed("Couldn't load bags. Please try again.") }
        }
    }

    public func resolveLocation() async {
        let location = await dependencies.location.resolve()
        var catalog = self.catalog
        catalog.location = location
        apply(catalog, now: dependencies.clock.now)
    }

    public func retry() async {
        state = .loading
        await load()
    }

    private func apply(_ catalog: OfferCatalog, now: Date) {
        self.catalog = catalog
        self.now = now
        map.update(catalog: catalog, now: now)
        state = catalog.offers.isEmpty ? .empty : .loaded
    }

    // MARK: - Actions

    public func toggleFavorite(restaurantID: String) async {
        guard flags.favorites else { return }
        let isFavorite = catalog.favoriteIDs.contains(restaurantID)
        catalog.favoriteIDs.formSymmetricDifference([restaurantID])  // optimistic
        do {
            try await dependencies.favorites.setFavorite(!isFavorite, restaurantID: restaurantID)
        } catch {
            catalog.favoriteIDs.formSymmetricDifference([restaurantID])
        }
    }

    // MARK: - Output

    /// Why distances come from LIC instead of the device, if they do.
    public var fallbackReason: ResolvedLocation.FallbackReason? {
        if case .fallback(let reason) = catalog.location?.source { reason } else { nil }
    }

    public var header: DiscoverHeader {
        let visible = catalog.offers.filter { catalog.isReservable($0, at: now) }
        let matching = visible.filter(catalog.matchesPreferences).count
        let prefs = catalog.preferences
        return DiscoverHeader(
            greetingName: prefs.name.isEmpty ? nil : prefs.name,
            homeArea: prefs.homeArea,
            availableCount: matching,
            hiddenByPreferencesCount: visible.count - matching,
            maxDistanceText: prefs.maxDistanceMiles.formatted(.number.precision(.fractionLength(0...2))),
            hiddenReasonText: flags.dietaryFilters ? "your distance or dietary preferences" : "your distance preference"
        )
    }

    /// Filtered and sorted, with bags you can't reserve pushed to the bottom; split
    /// into Tonight and Tomorrow once tomorrow's offers are visible.
    public var sections: [DiscoverSection] {
        let listed = catalog.offers
            .filter { category == nil || $0.category == category }
            .filter(catalog.matchesPreferences)
        guard OfferVisibility.showsTomorrow(at: now, calendar: catalog.calendar) else {
            return [DiscoverSection(kind: .all, items: items(listed))]
        }
        let today = NYCalendar.dayKey(for: now)
        let (tonight, tomorrow) = listed.reduce(into: ([Offer](), [Offer]())) { parts, offer in
            if NYCalendar.dayKey(for: offer.pickupWindow.start) == today {
                parts.0.append(offer)
            } else {
                parts.1.append(offer)
            }
        }
        return [
            DiscoverSection(kind: .tonight, items: items(tonight)),
            DiscoverSection(kind: .tomorrow, items: items(tomorrow)),
        ].filter { !$0.items.isEmpty }
    }

    public var isListEmpty: Bool { sections.allSatisfy(\.items.isEmpty) }

    private func items(_ offers: [Offer]) -> [DiscoverItem] {
        sorted(offers).compactMap { offer in
            catalog.card(for: offer, at: now).map {
                DiscoverItem(
                    offerID: offer.id, restaurantID: offer.restaurantID, card: $0,
                    isFavorite: catalog.favoriteIDs.contains(offer.restaurantID))
            }
        }
    }

    private func sorted(_ offers: [Offer]) -> [Offer] {
        offers.sorted { a, b in
            let aOpen = catalog.isReservable(a, at: now)
            let bOpen = catalog.isReservable(b, at: now)
            if aOpen != bOpen { return aOpen }
            switch sort {
            case .endingSoon:
                return (a.pickupWindow.end, a.id) < (b.pickupWindow.end, b.id)
            case .nearest:
                return (catalog.distanceMiles(to: a), a.id) < (catalog.distanceMiles(to: b), b.id)
            case .cheapest:
                return (a.price.cents, a.id) < (b.price.cents, b.id)
            }
        }
    }
}
