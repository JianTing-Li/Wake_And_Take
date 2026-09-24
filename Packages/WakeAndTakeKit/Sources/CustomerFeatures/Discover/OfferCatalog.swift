//
//  OfferCatalog.swift
//  WakeAndTakeKit
//
//  A loaded snapshot of what Discover and the map show, plus the pure logic
//  that turns an offer into card copy. Views never filter; this does.
//

import DesignSystem
import Domain
import Foundation
import Platform

struct OfferCatalog: Sendable {
    var offers: [Offer] = []
    var restaurants: [String: Restaurant] = [:]
    var favoriteIDs: Set<String> = []
    var preferences = UserPreferences()
    var commute = CommuteProfile()
    /// Nil until resolved; distances use the service-area center meanwhile.
    var location: ResolvedLocation?
    var flags: FeatureFlags

    var calendar: Calendar { NYCalendar.calendar }

    var origin: ResolvedLocation {
        location ?? ResolvedLocation(coordinate: ServiceArea.longIslandCity.center, source: .device)
    }

    func restaurant(for offer: Offer) -> Restaurant? {
        restaurants[offer.restaurantID]
    }

    func distanceMiles(to offer: Offer) -> Double {
        guard let restaurant = restaurant(for: offer) else { return .infinity }
        return PreferenceMatcher.distanceMiles(to: restaurant.coordinate, from: origin)
    }

    /// Distance, and diet when that flag is on.
    func matchesPreferences(_ offer: Offer) -> Bool {
        guard let restaurant = restaurant(for: offer) else { return false }
        return PreferenceMatcher.matches(
            offer, restaurant: restaurant.coordinate, location: origin, preferences: preferences,
            dietaryFiltersEnabled: flags.dietaryFilters)
    }

    func isReservable(_ offer: Offer, at now: Date) -> Bool {
        OfferAvailability.status(of: offer, at: now).isReservable
    }

    func fitsCommute(_ offer: Offer) -> Bool {
        flags.commute && CommuteMatcher.fits(offer.pickupWindow, profile: commute, calendar: calendar)
    }

    /// "0.3 mi away"
    func distanceText(to offer: Offer) -> String {
        String(format: "%.1f mi away", distanceMiles(to: offer))
    }

    func card(for offer: Offer, at now: Date) -> BagCard.Content? {
        guard let restaurant = restaurant(for: offer) else { return nil }
        let status = OfferAvailability.status(of: offer, at: now)
        return BagCard.Content(
            restaurantName: restaurant.name,
            bagName: offer.name,
            category: offer.category,
            badgeText: OfferAvailability.badgeText(for: offer, at: now, calendar: calendar),
            isUrgent: status == .endingSoon,
            savingsPercent: offer.savingsPercent,
            rating: flags.reviews ? restaurant.rating : nil,
            reviewCount: restaurant.reviewCount,
            pickupText: PickupDayFormatter.short(offer.pickupWindow, now: now, calendar: calendar),
            distanceText: distanceText(to: offer),
            price: offer.price,
            estimatedValue: offer.estimatedValue,
            isAvailable: status.isReservable,
            fitsCommute: fitsCommute(offer)
        )
    }
}
