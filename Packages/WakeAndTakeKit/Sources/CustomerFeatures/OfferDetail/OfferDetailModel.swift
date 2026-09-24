//
//  OfferDetailModel.swift
//  WakeAndTakeKit
//

import DesignSystem
import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class OfferDetailModel {
    public enum State: Equatable {
        case loading, loaded, notFound
        case failed(String)
    }

    public private(set) var state: State = .loading
    public private(set) var isFavorite = false
    public let reserve: ReserveModel

    private(set) var offer: Offer?
    private(set) var restaurant: Restaurant?
    private var now: Date
    private let offerID: String
    private let origin: ResolvedLocation
    private let dependencies: CustomerDependencies
    private let navigation: CustomerNavigation

    /// - Parameter origin: Where distances are measured from (the list's resolved location).
    public init(
        offerID: String, origin: ResolvedLocation, dependencies: CustomerDependencies,
        navigation: CustomerNavigation
    ) {
        self.offerID = offerID
        self.origin = origin
        self.dependencies = dependencies
        self.navigation = navigation
        now = dependencies.clock.now
        reserve = ReserveModel(offerID: offerID, dependencies: dependencies)
    }

    public var flags: FeatureFlags { dependencies.flags }
    /// Heart in the toolbar (favorites flag).
    public var showsFavoriteButton: Bool { flags.favorites }
    private var calendar: Calendar { NYCalendar.calendar }

    // MARK: - Lifecycle

    public func run() async {
        await load()
        let offers = dependencies.offers.changes()
        let userData = dependencies.favorites.changes()
        let clockChanges = dependencies.clock.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in offers { await self.load() } }
            group.addTask { for await _ in userData { await self.load() } }
            group.addTask { for await _ in clockChanges { await self.load() } }
            group.addTask {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    await self.load()
                }
            }
        }
    }

    public func load() async {
        now = dependencies.clock.now
        do {
            guard let offer = try await dependencies.offers.offer(id: offerID),
                let restaurant = try await dependencies.offers.restaurant(id: offer.restaurantID)
            else {
                state = .notFound
                return
            }
            self.offer = offer
            self.restaurant = restaurant
            isFavorite = try await dependencies.favorites.favorites().contains { $0.restaurantID == restaurant.id }
            reserve.update(quantityLeft: offer.quantityLeft)
            state = .loaded
        } catch {
            if state == .loading { state = .failed("Couldn't load this bag. Please try again.") }
        }
    }

    // MARK: - Actions

    public func toggleFavorite() async {
        guard flags.favorites, let restaurant else { return }
        isFavorite.toggle()
        do {
            try await dependencies.favorites.setFavorite(isFavorite, restaurantID: restaurant.id)
        } catch {
            isFavorite.toggle()
        }
    }

    /// From the confirmation: show the new order in the Orders tab.
    public func viewOrder(_ confirmation: ReservationConfirmation) {
        reserve.confirmation = nil
        navigation.discoverPath = []
        navigation.favoritesPath = []
        navigation.showOrder(confirmation.id)
    }

    // MARK: - Output

    private var status: OfferAvailability.Status? {
        offer.map { OfferAvailability.status(of: $0, at: now) }
    }

    /// Reservable now: in stock, window not over, and visible (tomorrow only after 20:00).
    public var canReserve: Bool {
        guard let offer, let status else { return false }
        return status.isReservable && OfferVisibility.isVisible(offer, at: now, calendar: calendar)
    }

    public var restaurantName: String { restaurant?.name ?? "" }
    public var bagName: String { offer?.name ?? "" }
    public var category: FoodCategory { offer?.category ?? .meal }
    public var summary: String { offer?.summary ?? "" }
    public var dietary: [DietaryTag] { DietaryTag.allCases.filter { offer?.dietary.contains($0) == true } }
    public var price: Money { offer?.price ?? .zero }
    public var estimatedValue: Money { offer?.estimatedValue ?? .zero }
    public var savingsPercent: Int { offer?.savingsPercent ?? 0 }
    public var coordinate: Coordinate? { restaurant?.coordinate }

    public var badgeText: String {
        offer.map { OfferAvailability.badgeText(for: $0, at: now, calendar: calendar) } ?? ""
    }
    public var isUrgent: Bool { status == .endingSoon }

    /// "4.8 (212 ratings) · Breakfast", or just the category when reviews are off.
    public var subtitle: String {
        guard flags.reviews, let restaurant else { return category.label }
        return String(format: "%.1f (%d ratings) · %@", restaurant.rating, restaurant.reviewCount, category.label)
    }

    /// "Pick up tomorrow, Fri Sep 25, 7:30–10:00 AM"
    public var pickupText: String {
        offer.map { PickupDayFormatter.full($0.pickupWindow, now: now, calendar: calendar) } ?? ""
    }

    /// "Opens tomorrow at 7:30 AM", "Ends in 25 min", "Sold out".
    public var urgencyText: String {
        offer.map { OfferAvailability.urgencyText(for: $0, at: now, calendar: calendar) } ?? ""
    }

    public var addressTitle: String { restaurant?.address.intersection ?? "" }

    /// "0.2 mi away · Long Island City"
    public var addressSubtitle: String {
        guard let restaurant else { return "" }
        let miles = PreferenceMatcher.distanceMiles(to: restaurant.coordinate, from: origin)
        return String(format: "%.1f mi away · %@", miles, restaurant.address.neighborhood)
    }

    /// "Reserve · $11.98", or why you can't.
    public var reserveButtonTitle: String {
        guard let offer else { return "" }
        if canReserve { return "Reserve · \((offer.price * reserve.quantity).usd)" }
        if !OfferVisibility.isVisible(offer, at: now, calendar: calendar), !offer.pickupWindow.hasEnded(at: now) {
            return ReserveModel.Alert.notOpenYet.title
        }
        return urgencyText
    }
}
