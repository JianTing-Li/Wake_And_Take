//
//  OfferVisibilityTests.swift
//  DomainTests
//

import Foundation
import Testing

@testable import Domain

@Suite("OfferVisibility")
struct OfferVisibilityTests {
    let cal = Fixtures.ny
    let today = Fixtures.window(7, 30, to: 10, 0, day: 24)
    let tomorrow = Fixtures.window(7, 30, to: 10, 0, day: 25)
    let dayAfter = Fixtures.window(7, 30, to: 10, 0, day: 26)
    let yesterday = Fixtures.window(21, 0, to: 23, 59, day: 23)

    @Test func todayIsAlwaysVisible() {
        #expect(OfferVisibility.isVisible(today, at: Fixtures.date(0, 0), calendar: cal))
        #expect(OfferVisibility.isVisible(today, at: Fixtures.date(23, 59), calendar: cal))
    }

    @Test func tomorrowAppearsAtEightPMNewYork() {
        let at1959 = Fixtures.date(19, 59)
        let at2000 = Fixtures.date(20, 0)
        #expect(!OfferVisibility.isVisible(tomorrow, at: at1959, calendar: cal))
        #expect(OfferVisibility.isVisible(tomorrow, at: at2000, calendar: cal))
        #expect(!OfferVisibility.showsTomorrow(at: at1959, calendar: cal))
        #expect(OfferVisibility.showsTomorrow(at: at2000, calendar: cal))
        #expect(OfferVisibility.tomorrowCutoffHour == 20)
    }

    @Test func acrossMidnightTomorrowBecomesToday() {
        let at2359 = Fixtures.date(23, 59)
        let atMidnight = Fixtures.date(0, 0, day: 25)
        #expect(OfferVisibility.isVisible(tomorrow, at: at2359, calendar: cal))
        #expect(OfferVisibility.isVisible(tomorrow, at: atMidnight, calendar: cal))
        // The day after is hidden until 8 PM on the 25th.
        #expect(!OfferVisibility.isVisible(dayAfter, at: atMidnight, calendar: cal))
        #expect(OfferVisibility.isVisible(dayAfter, at: Fixtures.date(20, 0, day: 25), calendar: cal))
        // Yesterday's offers disappear at midnight.
        #expect(!OfferVisibility.isVisible(today, at: atMidnight, calendar: cal))
    }

    @Test func pastAndFarFutureDaysAreHidden() {
        #expect(!OfferVisibility.isVisible(yesterday, at: Fixtures.date(8, 0), calendar: cal))
        #expect(!OfferVisibility.isVisible(dayAfter, at: Fixtures.date(21, 0), calendar: cal))
    }

    @Test func usesNewYorkTimeNotUTC() {
        // 8:30 PM New York is 00:30 UTC the next day; the NY rule must still say "tomorrow is visible".
        let now = Fixtures.date(20, 30)
        #expect(OfferVisibility.isVisible(tomorrow, at: now, calendar: cal))
        #expect(OfferVisibility.isVisible(today, at: now, calendar: cal))
    }

    @Test func offerOverloadUsesItsWindow() {
        let offer = Fixtures.offer(window: tomorrow)
        #expect(!OfferVisibility.isVisible(offer, at: Fixtures.date(12, 0), calendar: cal))
        #expect(OfferVisibility.isVisible(offer, at: Fixtures.date(20, 0), calendar: cal))
    }
}
