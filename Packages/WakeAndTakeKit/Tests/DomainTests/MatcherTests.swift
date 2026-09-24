//
//  MatcherTests.swift
//  DomainTests
//

import Foundation
import Testing

@testable import Domain

@Suite("PreferenceMatcher")
struct PreferenceMatcherTests {
    let here = ResolvedLocation(coordinate: Fixtures.licCenter, source: .device)
    /// About 0.24 mi from the LIC center.
    let near = Coordinate(latitude: 40.7443, longitude: -73.9532)
    /// Plaza Perk, about 0.54 mi away.
    let farther = Coordinate(latitude: 40.7497, longitude: -73.9390)

    @Test func distanceLimit() {
        var prefs = UserPreferences(maxDistanceMiles: 0.25)
        #expect(PreferenceMatcher.isWithinDistance(near, of: here, preferences: prefs))
        #expect(!PreferenceMatcher.isWithinDistance(farther, of: here, preferences: prefs))
        prefs.maxDistanceMiles = 1.0
        #expect(PreferenceMatcher.isWithinDistance(farther, of: here, preferences: prefs))
    }

    @Test func dietaryMustBeSuperset() {
        let veganBag = Fixtures.offer(dietary: [.vegetarian, .vegan, .dairyFree])
        let plainBag = Fixtures.offer(dietary: [])
        let prefs = UserPreferences(dietary: [.vegan, .dairyFree])
        #expect(PreferenceMatcher.suitsDiet(veganBag, preferences: prefs))
        #expect(!PreferenceMatcher.suitsDiet(plainBag, preferences: prefs))
        #expect(PreferenceMatcher.suitsDiet(plainBag, preferences: UserPreferences()))
    }

    @Test func dietaryIgnoredWhenFlagOff() {
        let plainBag = Fixtures.offer(dietary: [])
        let prefs = UserPreferences(maxDistanceMiles: 1.0, dietary: [.vegan])
        #expect(
            !PreferenceMatcher.matches(
                plainBag, restaurant: near, location: here, preferences: prefs,
                dietaryFiltersEnabled: true))
        #expect(
            PreferenceMatcher.matches(
                plainBag, restaurant: near, location: here, preferences: prefs,
                dietaryFiltersEnabled: false))
    }

    @Test func distanceStillAppliesWhenDietaryFlagOff() {
        let prefs = UserPreferences(maxDistanceMiles: 0.25)
        #expect(
            !PreferenceMatcher.matches(
                Fixtures.offer(), restaurant: farther, location: here,
                preferences: prefs, dietaryFiltersEnabled: false))
    }
}

@Suite("CommuteMatcher")
struct CommuteMatcherTests {
    let cal = Fixtures.ny
    /// Leave 7:30, arrive 8:30, weekdays.
    let profile = CommuteProfile()

    @Test func commuteWindowOnWeekdays() {
        // Thu Sep 24 is a weekday.
        let window = CommuteMatcher.commuteWindow(for: profile, on: Fixtures.date(6, 0), calendar: cal)
        #expect(window == Fixtures.date(7, 30)...Fixtures.date(8, 30))
        // Sat Sep 26 isn't.
        #expect(CommuteMatcher.commuteWindow(for: profile, on: Fixtures.date(6, 0, day: 26), calendar: cal) == nil)
    }

    @Test func invalidTimesHaveNoWindow() {
        let backwards = CommuteProfile(leaveMinutes: 9 * 60, arriveMinutes: 8 * 60)
        #expect(!backwards.isValid)
        #expect(CommuteMatcher.commuteWindow(for: backwards, on: Fixtures.date(6, 0), calendar: cal) == nil)
    }

    @Test func overlapFits() {
        #expect(CommuteMatcher.fits(Fixtures.window(7, 0, to: 10, 0), profile: profile, calendar: cal))
        #expect(CommuteMatcher.fits(Fixtures.window(8, 0, to: 8, 15), profile: profile, calendar: cal))
        // Touching edges don't overlap.
        #expect(!CommuteMatcher.fits(Fixtures.window(8, 30, to: 10, 0), profile: profile, calendar: cal))
        #expect(!CommuteMatcher.fits(Fixtures.window(6, 0, to: 7, 30), profile: profile, calendar: cal))
        #expect(!CommuteMatcher.fits(Fixtures.window(12, 0, to: 14, 0), profile: profile, calendar: cal))
    }

    @Test func tomorrowsWindowUsesTomorrowsCommute() {
        // Fri Sep 25 is a commute day; Sun Sep 27 isn't.
        #expect(CommuteMatcher.fits(Fixtures.window(7, 30, to: 10, 0, day: 25), profile: profile, calendar: cal))
        #expect(!CommuteMatcher.fits(Fixtures.window(7, 30, to: 10, 0, day: 27), profile: profile, calendar: cal))
    }

    @Test func dstMorningKeepsWallClockTimes() {
        // Nov 1, 2026 is a DST change day; make it a commute day (Sunday = 1).
        let sunday = CommuteProfile(commuteDays: [1])
        let window = CommuteMatcher.commuteWindow(
            for: sunday, on: Fixtures.date(6, 0, day: 1, month: 11), calendar: cal)
        #expect(window?.lowerBound == Fixtures.date(7, 30, day: 1, month: 11))
    }
}
