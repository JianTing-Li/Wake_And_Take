//
//  OfferAvailabilityTests.swift
//  DomainTests
//

import Foundation
import Testing

@testable import Domain

@Suite("OfferAvailability")
struct OfferAvailabilityTests {
    let cal = Fixtures.ny
    typealias Status = OfferAvailability.Status

    @Test(arguments: [
        (6, 0, 5, 1, Status.upcoming),
        (8, 0, 5, 1, .available),
        (8, 0, 5, 4, .almostGone),  // 1 left
        (9, 31, 5, 1, .endingSoon),  // 29 min left
        (9, 30, 5, 1, .available),  // exactly 30 min left isn't "ending soon"
        (9, 45, 5, 4, .endingSoon),  // ending soon wins over almost gone
        (8, 0, 5, 5, .soldOut),
        (10, 0, 5, 1, .ended),
        (10, 0, 5, 5, .soldOut),  // sold out wins over ended, like the draft
        (6, 0, 5, 4, .upcoming),  // not open yet stays upcoming even with 1 left
    ])
    func status(hour: Int, minute: Int, total: Int, reserved: Int, expected: Status) {
        let offer = Fixtures.offer(total: total, reserved: reserved)
        #expect(OfferAvailability.status(of: offer, at: Fixtures.date(hour, minute)) == expected)
    }

    @Test func reservableStates() {
        #expect(Status.upcoming.isReservable)
        #expect(Status.available.isReservable)
        #expect(Status.almostGone.isReservable)
        #expect(Status.endingSoon.isReservable)
        #expect(!Status.soldOut.isReservable)
        #expect(!Status.ended.isReservable)
        #expect(!Status.upcoming.isOpenNow)
        #expect(Status.endingSoon.isOpenNow)
    }

    @Test func urgencyCopy() {
        let offer = Fixtures.offer()
        #expect(OfferAvailability.urgencyText(for: offer, at: Fixtures.date(6, 0), calendar: cal) == "Opens at 7:30 AM")
        #expect(OfferAvailability.urgencyText(for: offer, at: Fixtures.date(9, 35), calendar: cal) == "Ends in 25 min")
        #expect(OfferAvailability.urgencyText(for: offer, at: Fixtures.date(10, 5), calendar: cal) == "Pickup ended")
        let soldOut = Fixtures.offer(total: 2, reserved: 2)
        #expect(OfferAvailability.urgencyText(for: soldOut, at: Fixtures.date(8, 0), calendar: cal) == "Sold out")
    }

    @Test func badgeCopy() {
        let offer = Fixtures.offer(total: 5, reserved: 2)
        #expect(OfferAvailability.badgeText(for: offer, at: Fixtures.date(8, 0), calendar: cal) == "3 left")
        #expect(OfferAvailability.badgeText(for: offer, at: Fixtures.date(9, 40), calendar: cal) == "Ends in 20 min")
        #expect(OfferAvailability.badgeText(for: offer, at: Fixtures.date(7, 0), calendar: cal) == "Opens at 7:30 AM")
        let lastOne = Fixtures.offer(total: 5, reserved: 4)
        #expect(OfferAvailability.badgeText(for: lastOne, at: Fixtures.date(8, 0), calendar: cal) == "1 left")
    }

    @Test func tomorrowsUpcomingOfferSaysTomorrow() {
        let offer = Fixtures.offer(window: Fixtures.window(7, 30, to: 10, 0, day: 25))
        #expect(
            OfferAvailability.badgeText(for: offer, at: Fixtures.date(20, 15), calendar: cal)
                == "Opens tomorrow at 7:30 AM")
    }
}
