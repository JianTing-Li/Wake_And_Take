//
//  ClockAndCalendarTests.swift
//  PlatformTests
//

import Domain
import Foundation
import Testing

@testable import Platform

@Suite("NYCalendar")
struct NYCalendarTests {
    let cal = NYCalendar.calendar

    @Test func dayKeyIsNewYorkDay() throws {
        let key = DayKey(rawValue: "2026-09-24")
        let lateNight = try #require(NYCalendar.date(on: key, hour: 23, minute: 30))
        #expect(NYCalendar.dayKey(for: lateNight) == key)
        #expect(NYCalendar.dayKey(for: lateNight.addingTimeInterval(31 * 60)).rawValue == "2026-09-25")
    }

    @Test func dayAfterCrossesMonthsAndYears() {
        #expect(NYCalendar.day(after: DayKey(rawValue: "2026-09-30")).rawValue == "2026-10-01")
        #expect(NYCalendar.day(after: DayKey(rawValue: "2026-12-31")).rawValue == "2027-01-01")
    }

    @Test func wallClockTimesSurviveDST() throws {
        // Nov 1, 2026: clocks fall back at 2 AM. 7:30 AM must still be 7:30 AM.
        let key = DayKey(rawValue: "2026-11-01")
        let morning = try #require(NYCalendar.date(on: key, hour: 7, minute: 30))
        let parts = cal.dateComponents([.hour, .minute], from: morning)
        #expect(parts.hour == 7 && parts.minute == 30)
        // That day is 25 hours long.
        let start = try #require(NYCalendar.startOfDay(key))
        let next = try #require(NYCalendar.startOfDay(NYCalendar.day(after: key)))
        #expect(next.timeIntervalSince(start) == 25 * 3600)
    }

    @Test func invalidKeyHasNoDate() {
        #expect(NYCalendar.date(on: DayKey(rawValue: "nope"), hour: 7, minute: 0) == nil)
    }
}

@Suite("Clocks")
struct ClockTests {
    let start = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func fixedClockStaysPut() {
        let clock = AdjustableClock(fixedAt: start)
        #expect(clock.now == start)
        #expect(clock.now == start)
    }

    @Test func travelAdvanceAndReset() {
        let clock = AdjustableClock(fixedAt: start)
        clock.advance(by: 3600)
        #expect(clock.now == start.addingTimeInterval(3600))
        clock.travel(to: start.addingTimeInterval(-86_400))
        #expect(clock.now == start.addingTimeInterval(-86_400))
        clock.resetToLive()
        #expect(clock.isLive)
        #expect(abs(clock.now.timeIntervalSince(LiveClock().now)) < 1)
    }

    @Test func offsetClockRunsAtLiveSpeedWithOffset() {
        let clock = AdjustableClock(offset: 7200)
        #expect(abs(clock.now.timeIntervalSince(LiveClock().now) - 7200) < 1)
        #expect(!clock.isLive)
    }

    @Test func changesAreBroadcast() async {
        let clock = AdjustableClock(fixedAt: start)
        var first = clock.changes().makeAsyncIterator()
        var second = clock.changes().makeAsyncIterator()
        clock.advance(by: 60)
        #expect(await first.next() != nil)
        #expect(await second.next() != nil)
    }
}

@Suite("Broadcaster")
struct BroadcasterTests {
    @Test func listenersAreRemovedWhenStreamsEnd() async {
        let broadcaster = Broadcaster<Int>()
        do {
            let stream = broadcaster.stream()
            #expect(broadcaster.listenerCount == 1)
            broadcaster.send(1)
            var iterator = stream.makeAsyncIterator()
            #expect(await iterator.next() == 1)
        }
        // Dropping the stream terminates it.
        #expect(broadcaster.listenerCount == 0)
    }
}
