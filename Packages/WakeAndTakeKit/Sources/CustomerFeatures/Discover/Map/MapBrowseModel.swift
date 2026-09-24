//
//  MapBrowseModel.swift
//  WakeAndTakeKit
//
//  User Journey 6: a customer browses nearby stores with bags on a map
//  and taps a pin to view and reserve a bag.
//

import DesignSystem
import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class MapBrowseModel {
    /// After 20:00 New York the map shows one day at a time instead of mixing pins.
    public enum Day: String, CaseIterable, Identifiable, Sendable {
        case tonight = "Tonight"
        case tomorrow = "Tomorrow"
        public var id: String { rawValue }
    }

    public struct Pin: Identifiable, Hashable, Sendable {
        public var id: String { offerID }
        public let offerID: String
        public let coordinate: Coordinate
        public let category: FoodCategory
        public let price: Money
        public let state: PricePin.State
        public let accessibilityText: String
    }

    public var day: Day = .tonight {
        didSet { dropSelectionIfHidden() }
    }
    public var selectedOfferID: String?

    private var catalog: OfferCatalog
    private var now: Date

    init(catalog: OfferCatalog, now: Date) {
        self.catalog = catalog
        self.now = now
    }

    func update(catalog: OfferCatalog, now: Date) {
        self.catalog = catalog
        self.now = now
        if !showsDayPicker { day = .tonight }
        dropSelectionIfHidden()
    }

    // MARK: - Output

    public var showsDayPicker: Bool {
        OfferVisibility.showsTomorrow(at: now, calendar: catalog.calendar)
    }

    /// Where "you" are: the device, or the LIC center as a fallback.
    public var center: Coordinate { catalog.origin.coordinate }
    public var maxDistanceMiles: Double { catalog.preferences.maxDistanceMiles }
    public var maxDistanceText: String {
        maxDistanceMiles.formatted(.number.precision(.fractionLength(0...2)))
    }

    public var pins: [Pin] {
        shownOffers.compactMap { offer in
            guard let restaurant = catalog.restaurant(for: offer) else { return nil }
            let status = OfferAvailability.status(of: offer, at: now)
            let state: PricePin.State =
                status.isOpenNow ? .openNow : status == .upcoming ? .opensLater : .gone
            let urgency = OfferAvailability.urgencyText(for: offer, at: now, calendar: catalog.calendar)
            return Pin(
                offerID: offer.id, coordinate: restaurant.coordinate, category: offer.category,
                price: offer.price, state: state,
                accessibilityText: "\(restaurant.name), \(urgency), \(offer.price.usd)")
        }
    }

    /// Bags you could still reserve among the pins.
    public var availableCount: Int {
        shownOffers.filter { catalog.isReservable($0, at: now) }.count
    }

    public var selectedCard: MapBagCard.Content? {
        guard let id = selectedOfferID, let offer = shownOffers.first(where: { $0.id == id }),
            let restaurant = catalog.restaurant(for: offer)
        else { return nil }
        let status = OfferAvailability.status(of: offer, at: now)
        let urgency = OfferAvailability.urgencyText(for: offer, at: now, calendar: catalog.calendar)
        return MapBagCard.Content(
            restaurantName: restaurant.name,
            bagName: offer.name,
            category: offer.category,
            statusLine: "\(urgency) · \(String(format: "%.1f mi", catalog.distanceMiles(to: offer)))",
            isUrgent: status == .endingSoon,
            price: offer.price,
            estimatedValue: offer.estimatedValue,
            isAvailable: status.isReservable
        )
    }

    public func select(_ offerID: String?) {
        selectedOfferID = offerID
    }

    // MARK: - Filtering

    /// Offers matching preferences, limited to the chosen day after 20:00.
    private var shownOffers: [Offer] {
        let matching = catalog.offers.filter(catalog.matchesPreferences)
        guard showsDayPicker else { return matching }
        let today = NYCalendar.dayKey(for: now)
        return matching.filter { (NYCalendar.dayKey(for: $0.pickupWindow.start) == today) == (day == .tonight) }
    }

    private func dropSelectionIfHidden() {
        if let id = selectedOfferID, !shownOffers.contains(where: { $0.id == id }) {
            selectedOfferID = nil
        }
    }
}
