//
//  ReservationPolicyTests.swift
//  DomainTests
//

import Foundation
import Testing

@testable import Domain

@Suite("ReservationPolicy")
struct ReservationPolicyTests {
    let cal = Fixtures.ny
    typealias Status = ReservationPolicy.Status

    // MARK: Status

    @Test func statusFollowsTheSnapshotWindow() {
        let r = Fixtures.reservation()  // 7:30–10:00
        #expect(ReservationPolicy.status(of: r, at: Fixtures.date(7, 29)) == .upcoming)
        #expect(ReservationPolicy.status(of: r, at: Fixtures.date(7, 30)) == .readyNow)
        #expect(ReservationPolicy.status(of: r, at: Fixtures.date(9, 59)) == .readyNow)
        #expect(ReservationPolicy.status(of: r, at: Fixtures.date(10, 0)) == .missed)
    }

    @Test func collectedAndCancelledOverrideTheWindow() {
        let collected = Fixtures.reservation(collectedAt: Fixtures.date(8, 0))
        #expect(ReservationPolicy.status(of: collected, at: Fixtures.date(11, 0)) == .collected)
        let cancelled = Fixtures.reservation(cancelledAt: Fixtures.date(7, 0))
        #expect(ReservationPolicy.status(of: cancelled, at: Fixtures.date(8, 0)) == .cancelled)
        #expect(!ReservationPolicy.isActive(cancelled, at: Fixtures.date(8, 0)))
        #expect(!ReservationPolicy.isActive(collected, at: Fixtures.date(8, 0)))
    }

    @Test func activeMeansUpcomingOrReady() {
        let r = Fixtures.reservation()
        #expect(ReservationPolicy.isActive(r, at: Fixtures.date(6, 0)))
        #expect(ReservationPolicy.isActive(r, at: Fixtures.date(8, 0)))
        #expect(!ReservationPolicy.isActive(r, at: Fixtures.date(10, 0)))
    }

    // MARK: Changes

    @Test func changeCutoffIsTenMinutesBeforeEnd() {
        let r = Fixtures.reservation()
        #expect(ReservationPolicy.changeDeadline(for: r) == Fixtures.date(9, 50))
        #expect(ReservationPolicy.canChange(r, at: Fixtures.date(9, 49)))
        #expect(!ReservationPolicy.canChange(r, at: Fixtures.date(9, 50)))
        #expect(throws: ReservationError.changeClosed) {
            try ReservationPolicy.validateCancel(of: r, at: Fixtures.date(9, 55))
        }
        #expect(throws: Never.self) { try ReservationPolicy.validateCancel(of: r, at: Fixtures.date(9, 0)) }
    }

    @Test func cannotChangeCancelledOrCollectedOrders() {
        let cancelled = Fixtures.reservation(cancelledAt: Fixtures.date(6, 30))
        #expect(!ReservationPolicy.canChange(cancelled, at: Fixtures.date(7, 0)))
        let collected = Fixtures.reservation(collectedAt: Fixtures.date(8, 0))
        #expect(!ReservationPolicy.canChange(collected, at: Fixtures.date(8, 1)))
    }

    @Test func maxQuantityIsThreeOrWhatIsLeft() {
        #expect(ReservationPolicy.maxQuantity == 3)
        #expect(ReservationPolicy.maxQuantity(forNewReservationWithLeft: 10) == 3)
        #expect(ReservationPolicy.maxQuantity(forNewReservationWithLeft: 2) == 2)
        #expect(ReservationPolicy.maxQuantity(forNewReservationWithLeft: 0) == 0)
        let holdingTwo = Fixtures.reservation(quantity: 2)
        #expect(ReservationPolicy.maxQuantity(forChanging: holdingTwo, offerQuantityLeft: 0) == 2)
        #expect(ReservationPolicy.maxQuantity(forChanging: holdingTwo, offerQuantityLeft: 5) == 3)
    }

    @Test func validateChangeChecksDeadlineAndStock() {
        let r = Fixtures.reservation(quantity: 2)
        let at = Fixtures.date(8, 0)
        #expect(throws: Never.self) { try ReservationPolicy.validateChange(of: r, to: 3, offerQuantityLeft: 1, at: at) }
        #expect(throws: Never.self) { try ReservationPolicy.validateChange(of: r, to: 1, offerQuantityLeft: 0, at: at) }
        #expect(throws: ReservationError.invalidQuantity) {
            try ReservationPolicy.validateChange(of: r, to: 3, offerQuantityLeft: 0, at: at)
        }
        #expect(throws: ReservationError.invalidQuantity) {
            try ReservationPolicy.validateChange(of: r, to: 0, offerQuantityLeft: 5, at: at)
        }
        #expect(throws: ReservationError.changeClosed) {
            try ReservationPolicy.validateChange(of: r, to: 1, offerQuantityLeft: 5, at: Fixtures.date(9, 51))
        }
    }

    // MARK: Collecting

    @Test func collectOnlyWhileReady() {
        let r = Fixtures.reservation()
        #expect(throws: ReservationError.notReadyForPickup) {
            try ReservationPolicy.validateCollect(of: r, at: Fixtures.date(7, 0))
        }
        #expect(throws: Never.self) { try ReservationPolicy.validateCollect(of: r, at: Fixtures.date(8, 0)) }
        #expect(throws: ReservationError.notReadyForPickup) {
            try ReservationPolicy.validateCollect(of: r, at: Fixtures.date(10, 0))
        }
        let done = Fixtures.reservation(collectedAt: Fixtures.date(8, 0))
        #expect(!ReservationPolicy.canCollect(done, at: Fixtures.date(8, 5)))
    }

    // MARK: Reserving

    @Test func validReservation() {
        let offer = Fixtures.offer(total: 5, reserved: 1)
        #expect(throws: Never.self) {
            try ReservationPolicy.validateReservation(of: offer, quantity: 3, at: Fixtures.date(6, 0), calendar: cal)
        }
    }

    @Test func reservationErrors() {
        let now = Fixtures.date(8, 0)
        #expect(throws: ReservationError.soldOut) {
            try ReservationPolicy.validateReservation(
                of: Fixtures.offer(total: 2, reserved: 2), quantity: 1, at: now, calendar: cal)
        }
        #expect(throws: ReservationError.windowClosed) {
            try ReservationPolicy.validateReservation(
                of: Fixtures.offer(), quantity: 1, at: Fixtures.date(10, 0), calendar: cal)
        }
        #expect(throws: ReservationError.invalidQuantity) {
            try ReservationPolicy.validateReservation(
                of: Fixtures.offer(total: 5, reserved: 3), quantity: 3, at: now, calendar: cal)
        }
        #expect(throws: ReservationError.invalidQuantity) {
            try ReservationPolicy.validateReservation(of: Fixtures.offer(), quantity: 0, at: now, calendar: cal)
        }
        #expect(throws: ReservationError.invalidQuantity) {
            try ReservationPolicy.validateReservation(
                of: Fixtures.offer(total: 10), quantity: 4, at: now, calendar: cal)
        }
    }

    @Test func tomorrowIsNotReservableBeforeEightPM() {
        let tomorrow = Fixtures.offer(window: Fixtures.window(7, 30, to: 10, 0, day: 25))
        #expect(throws: ReservationError.notVisibleYet) {
            try ReservationPolicy.validateReservation(
                of: tomorrow, quantity: 1, at: Fixtures.date(19, 59), calendar: cal)
        }
        #expect(throws: Never.self) {
            try ReservationPolicy.validateReservation(
                of: tomorrow, quantity: 1, at: Fixtures.date(20, 0), calendar: cal)
        }
    }

    @Test func yesterdaysOfferReadsAsClosed() {
        let yesterday = Fixtures.offer(window: Fixtures.window(7, 30, to: 10, 0, day: 23))
        #expect(throws: ReservationError.windowClosed) {
            try ReservationPolicy.validateReservation(
                of: yesterday, quantity: 1, at: Fixtures.date(8, 0), calendar: cal)
        }
    }
}
