//
//  ModelTests.swift
//  DomainTests
//

import Foundation
import Testing

@testable import Domain

@Suite("Models")
struct ModelTests {
    @Test func moneyArithmeticStaysInCents() {
        let price = Money(cents: 599)
        #expect(price * 3 == Money(cents: 1797))
        #expect(Money(cents: 1800) - price == Money(cents: 1201))
        var total = Money.zero
        total += price
        #expect(total == price)
        #expect(price.decimalDollars == Decimal(string: "5.99"))
        #expect(Money(cents: 100) < price)
    }

    @Test func dayKeyUsesTheCalendarTimeZone() {
        // 11:30 PM in New York is already the next day in UTC.
        let lateNight = Fixtures.date(23, 30)
        #expect(DayKey(lateNight, calendar: Fixtures.ny).rawValue == "2026-09-24")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        #expect(DayKey(lateNight, calendar: utc).rawValue == "2026-09-25")
        #expect(DayKey(rawValue: "2026-09-24") < DayKey(rawValue: "2026-09-25"))
    }

    @Test func offerIDCombinesTemplateAndDay() {
        let id = Offer.makeID(templateID: "tpl_early_bird_breakfast", day: DayKey(rawValue: "2026-09-25"))
        #expect(id == "tpl_early_bird_breakfast-2026-09-25")
        #expect(Fixtures.offer().id == "tpl_early_bird_breakfast-2026-09-24")
    }

    @Test func offerStockAndSavings() {
        let offer = Fixtures.offer(total: 5, reserved: 4, price: 599, value: 1800)
        #expect(offer.quantityLeft == 1)
        #expect(!offer.isSoldOut)
        #expect(offer.savingsPercent == 67)
        #expect(Fixtures.offer(total: 3, reserved: 3).isSoldOut)
        #expect(Fixtures.offer(total: 3, reserved: 5).quantityLeft == 0)
        #expect(Fixtures.offer(value: 0).savingsPercent == 0)
    }

    @Test func snapshotCopiesWhatTheCustomerSaw() {
        let offer = Fixtures.offer()
        let restaurant = Fixtures.restaurant()
        let snapshot = OfferSnapshot(offer: offer, restaurant: restaurant)
        #expect(snapshot.offerID == offer.id)
        #expect(snapshot.restaurantName == "Early Bird Bakehouse")
        #expect(snapshot.address.intersection == "Vernon Blvd & 48th Ave")
        #expect(snapshot.unitPrice == offer.price)
        #expect(snapshot.pickupWindow == offer.pickupWindow)
    }

    @Test func reservationTotalsUseTheSnapshot() {
        let r = Fixtures.reservation(quantity: 2, price: 599, value: 1800)
        #expect(r.total == Money(cents: 1198))
        #expect(r.savings == Money(cents: 2402))
    }

    @Test func distanceBetweenLICPointsIsInMiles() {
        let a = Fixtures.licCenter
        #expect(a.distanceMiles(to: a) == 0)
        // Roughly 0.24 mi between the service-area center and Early Bird Bakehouse.
        let d = a.distanceMiles(to: Coordinate(latitude: 40.7443, longitude: -73.9532))
        #expect(d > 0.2 && d < 0.3)
    }

    @Test func addressLines() {
        #expect(Fixtures.address.shortLine == "Vernon Blvd & 48th Ave, Long Island City")
        #expect(Fixtures.address.mapsQuery == "Vernon Blvd & 48th Ave, Queens, NY 11101")
    }

    @Test func featureFlagAlertsNeedFavorites() {
        var flags = FeatureFlags(
            mapBrowse: true, favorites: true, notifications: true, dietaryFilters: true,
            manageOrder: true, reviews: true, impact: true, commute: false
        )
        #expect(flags.alertsEnabled)
        flags.favorites = false
        #expect(!flags.alertsEnabled)
    }

    @Test func resolvedLocationFallbackFlag() {
        #expect(!ResolvedLocation(coordinate: Fixtures.licCenter, source: .device).isFallback)
        #expect(ResolvedLocation(coordinate: Fixtures.licCenter, source: .fallback(.noFix)).isFallback)
    }

    @Test func enumsDecodeFromStableRawValues() throws {
        let decoded = try JSONDecoder().decode([DietaryTag].self, from: Data(#"["vegan","dairyFree"]"#.utf8))
        #expect(decoded == [.vegan, .dairyFree])
        #expect(FoodCategory(rawValue: "meal") == .meal)
        #expect(CancelReason.plansChanged.label == "My plans changed")
        #expect(ReviewTag.longWait.isPositive == false)
    }
}
