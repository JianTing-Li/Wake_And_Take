//
//  Fixtures.swift
//  DomainTests
//
//  A fixed New York calendar and builders so every test is deterministic.
//  Thursday, Sep 24 2026 is the default "today".
//

import Foundation

@testable import Domain

enum Fixtures {
    static let ny: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// A New York wall-clock time. Defaults to Thu Sep 24, 2026.
    static func date(
        _ hour: Int,
        _ minute: Int = 0,
        day: Int = 24,
        month: Int = 9,
        year: Int = 2026
    ) -> Date {
        ny.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func window(
        _ startHour: Int,
        _ startMinute: Int,
        to endHour: Int,
        _ endMinute: Int,
        day: Int = 24
    ) -> PickupWindow {
        PickupWindow(start: date(startHour, startMinute, day: day), end: date(endHour, endMinute, day: day))
    }

    static let address = Restaurant.Address(
        street: "Vernon Blvd",
        crossStreet: "48th Ave",
        neighborhood: "Long Island City",
        borough: "Queens",
        zip: "11101"
    )

    static let licCenter = Coordinate(latitude: 40.7455, longitude: -73.9490)

    static func restaurant(coordinate: Coordinate = Coordinate(latitude: 40.7443, longitude: -73.9532)) -> Restaurant {
        Restaurant(
            id: "rst_early_bird_bakehouse",
            name: "Early Bird Bakehouse",
            kind: .bakery,
            address: address,
            coordinate: coordinate,
            pickupInstructions: "Go to the side counter.",
            rating: 4.8,
            reviewCount: 212
        )
    }

    static func offer(
        window: PickupWindow = window(7, 30, to: 10, 0),
        total: Int = 5,
        reserved: Int = 1,
        price: Int = 599,
        value: Int = 1800,
        dietary: Set<DietaryTag> = []
    ) -> Offer {
        Offer(
            id: Offer.makeID(templateID: "tpl_early_bird_breakfast", day: DayKey(window.start, calendar: ny)),
            templateID: "tpl_early_bird_breakfast",
            restaurantID: "rst_early_bird_bakehouse",
            name: "Breakfast Surprise Bag",
            category: .breakfast,
            summary: "Likely a breakfast sandwich.",
            dietary: dietary,
            price: Money(cents: price),
            estimatedValue: Money(cents: value),
            quantityTotal: total,
            quantityReserved: reserved,
            pickupWindow: window
        )
    }

    static func reservation(
        window: PickupWindow = window(7, 30, to: 10, 0),
        quantity: Int = 1,
        price: Int = 599,
        value: Int = 1800,
        collectedAt: Date? = nil,
        cancelledAt: Date? = nil,
        review: Review? = nil
    ) -> Reservation {
        Reservation(
            id: UUID(),
            confirmationCode: "AB23",
            quantity: quantity,
            snapshot: OfferSnapshot(
                offer: offer(window: window, price: price, value: value),
                restaurant: restaurant()
            ),
            reservedAt: date(6, 0),
            collectedAt: collectedAt,
            cancelledAt: cancelledAt,
            review: review
        )
    }
}
