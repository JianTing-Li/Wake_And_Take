//
//  PickupDayFormatterTests.swift
//  DomainTests
//

import Foundation
import Testing

@testable import Domain

@Suite("PickupDayFormatter")
struct PickupDayFormatterTests {
    let cal = Fixtures.ny
    let morning = Fixtures.window(7, 30, to: 10, 0)
    let tomorrowMorning = Fixtures.window(7, 30, to: 10, 0, day: 25)
    let lateNight = Fixtures.window(21, 0, to: 23, 59)
    let lunch = Fixtures.window(11, 30, to: 14, 0)

    // MARK: Time text

    @Test func timesAndRanges() {
        #expect(TimeText.time(Fixtures.date(0, 5), calendar: cal) == "12:05 AM")
        #expect(TimeText.time(Fixtures.date(12, 0), calendar: cal) == "12:00 PM")
        #expect(TimeText.time(Fixtures.date(23, 59), calendar: cal) == "11:59 PM")
        #expect(TimeText.range(morning, calendar: cal) == "7:30–10:00 AM")
        #expect(TimeText.range(lunch, calendar: cal) == "11:30 AM–2:00 PM")
        #expect(TimeText.shortDate(tomorrowMorning.start, calendar: cal) == "Fri Sep 25")
    }

    // MARK: Day classification

    @Test func tonightStartsAtFivePM() {
        let at1659 = Fixtures.window(16, 59, to: 18, 0)
        let at1700 = Fixtures.window(17, 0, to: 19, 0)
        let now = Fixtures.date(8, 0)
        #expect(PickupDayFormatter.day(of: at1659, now: now, calendar: cal) == .today)
        #expect(PickupDayFormatter.day(of: at1700, now: now, calendar: cal) == .tonight)
    }

    @Test func tomorrowAndOtherDays() {
        let now = Fixtures.date(20, 15)
        #expect(PickupDayFormatter.day(of: tomorrowMorning, now: now, calendar: cal) == .tomorrow)
        let yesterday = Fixtures.window(7, 30, to: 10, 0, day: 23)
        #expect(PickupDayFormatter.dayLabel(for: yesterday, now: now, calendar: cal) == "Wed Sep 23")
        // Tomorrow's evening window is still "Tomorrow", not "Tonight".
        let tomorrowNight = Fixtures.window(21, 0, to: 23, 59, day: 25)
        #expect(PickupDayFormatter.dayLabel(for: tomorrowNight, now: now, calendar: cal) == "Tomorrow")
    }

    @Test func dayChangesAtNewYorkMidnight() {
        #expect(PickupDayFormatter.day(of: tomorrowMorning, now: Fixtures.date(23, 59), calendar: cal) == .tomorrow)
        #expect(PickupDayFormatter.day(of: tomorrowMorning, now: Fixtures.date(0, 0, day: 25), calendar: cal) == .today)
    }

    // MARK: Short

    @Test func shortCopy() {
        let now = Fixtures.date(6, 0)
        #expect(PickupDayFormatter.short(morning, now: now, calendar: cal) == "Today · 7:30–10:00 AM")
        #expect(PickupDayFormatter.short(lateNight, now: now, calendar: cal) == "Tonight · 9:00–11:59 PM")
        #expect(
            PickupDayFormatter.short(tomorrowMorning, now: Fixtures.date(20, 30), calendar: cal)
                == "Tomorrow · 7:30–10:00 AM")
    }

    @Test func shortCopyOnceOpenSaysUntil() {
        #expect(
            PickupDayFormatter.short(lateNight, now: Fixtures.date(21, 30), calendar: cal)
                == "Tonight · until 11:59 PM")
        #expect(
            PickupDayFormatter.short(morning, now: Fixtures.date(8, 0), calendar: cal)
                == "Today · until 10:00 AM")
        // After it ends it goes back to the range.
        #expect(
            PickupDayFormatter.short(morning, now: Fixtures.date(10, 0), calendar: cal)
                == "Today · 7:30–10:00 AM")
    }

    // MARK: Full

    @Test func fullDateCopy() {
        #expect(
            PickupDayFormatter.full(tomorrowMorning, now: Fixtures.date(20, 15), calendar: cal)
                == "Pick up tomorrow, Fri Sep 25, 7:30–10:00 AM")
        #expect(
            PickupDayFormatter.full(morning, now: Fixtures.date(6, 0), calendar: cal)
                == "Pick up today, Thu Sep 24, 7:30–10:00 AM")
        #expect(
            PickupDayFormatter.full(lateNight, now: Fixtures.date(6, 0), calendar: cal)
                == "Pick up tonight, Thu Sep 24, 9:00–11:59 PM")
        #expect(
            PickupDayFormatter.full(morning, now: Fixtures.date(9, 0, day: 26), calendar: cal)
                == "Pick up Thu Sep 24, 7:30–10:00 AM")
    }

    // MARK: Countdown

    @Test func countdownBeforeOpening() {
        #expect(
            PickupDayFormatter.countdown(lateNight, now: Fixtures.date(20, 0), calendar: cal)
                == "Opens at 9:00 PM")
        #expect(
            PickupDayFormatter.countdown(tomorrowMorning, now: Fixtures.date(20, 15), calendar: cal)
                == "Opens tomorrow at 7:30 AM")
        let later = Fixtures.window(7, 30, to: 10, 0, day: 27)
        #expect(
            PickupDayFormatter.countdown(later, now: Fixtures.date(8, 0), calendar: cal)
                == "Opens Sun Sep 27 at 7:30 AM")
    }

    @Test func countdownWhileOpen() {
        #expect(PickupDayFormatter.countdown(morning, now: Fixtures.date(8, 0), calendar: cal) == "Ends at 10:00 AM")
        #expect(PickupDayFormatter.countdown(morning, now: Fixtures.date(9, 0), calendar: cal) == "Ends at 10:00 AM")
        #expect(PickupDayFormatter.countdown(morning, now: Fixtures.date(9, 1), calendar: cal) == "Ends in 59 min")
        #expect(PickupDayFormatter.countdown(morning, now: Fixtures.date(9, 35), calendar: cal) == "Ends in 25 min")
        // Under a minute still reads as 1 min.
        let almost = Fixtures.date(10, 0).addingTimeInterval(-20)
        #expect(PickupDayFormatter.countdown(morning, now: almost, calendar: cal) == "Ends in 1 min")
    }

    @Test func countdownAfterEnd() {
        #expect(PickupDayFormatter.countdown(morning, now: Fixtures.date(10, 0), calendar: cal) == "Pickup ended")
    }
}
