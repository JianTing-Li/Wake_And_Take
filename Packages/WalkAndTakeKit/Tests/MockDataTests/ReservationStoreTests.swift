//
//  ReservationStoreTests.swift
//  MockDataTests
//
//  Early Bird breakfast: 5 bags, 1 simulated → 4 left, 7:30–10:00.
//  Knead Street morning: sold out at seed. Morning Tide: 1 left.
//

import Domain
import Foundation
import Platform
import Testing

@testable import MockData

@Suite("Reservations")
struct ReservationStoreTests {
    let earlyBird = TestEnv.offerID("tpl_early_bird_breakfast", day: 24)
    let kneadStreet = TestEnv.offerID("tpl_knead_street_morning", day: 24)

    func stores() async throws -> TestEnv.Stores {
        try await TestEnv.makeStores(rolloverAt: TestEnv.sep(24, 7))
    }

    @Test func reserveTakesStockAndSnapshotsTheOffer() async throws {
        let market = try await stores().marketplace
        let r = try await market.reserve(offerID: earlyBird, quantity: 2, at: TestEnv.sep(24, 7))
        #expect(r.quantity == 2)
        #expect(r.confirmationCode.count == 4)
        #expect(r.snapshot.unitPrice == Money(cents: 599))
        #expect(r.snapshot.pickupInstructions.contains("side counter"))
        #expect(r.total == Money(cents: 1198))
        #expect(try await market.offer(id: earlyBird)?.quantityLeft == 2)
        #expect(try await market.reservations() == [r])
    }

    @Test func reserveErrors() async throws {
        let market = try await stores().marketplace
        await #expect(throws: ReservationError.soldOut) {
            try await market.reserve(offerID: kneadStreet, quantity: 1, at: TestEnv.sep(24, 8))
        }
        await #expect(throws: ReservationError.windowClosed) {
            try await market.reserve(offerID: earlyBird, quantity: 1, at: TestEnv.sep(24, 10))
        }
        await #expect(throws: ReservationError.notVisibleYet) {
            try await market.reserve(
                offerID: TestEnv.offerID("tpl_early_bird_breakfast", day: 25), quantity: 1, at: TestEnv.sep(24, 19, 59))
        }
        await #expect(throws: ReservationError.invalidQuantity) {
            try await market.reserve(offerID: earlyBird, quantity: 4, at: TestEnv.sep(24, 8))
        }
        await #expect(throws: ReservationError.invalidQuantity) {
            try await market.reserve(offerID: earlyBird, quantity: 0, at: TestEnv.sep(24, 8))
        }
        await #expect(throws: ReservationError.offerNoLongerExists) {
            try await market.reserve(offerID: "tpl_nope-2026-09-24", quantity: 1, at: TestEnv.sep(24, 8))
        }
        // Nothing was taken by the failures.
        #expect(try await market.offer(id: earlyBird)?.quantityLeft == 4)
        #expect(try await market.reservations().isEmpty)
    }

    @Test func concurrentReservesCannotOversell() async throws {
        let market = try await stores().marketplace
        let now = TestEnv.sep(24, 8)
        let offerID = earlyBird
        let successes = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask { (try? await market.reserve(offerID: offerID, quantity: 1, at: now)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(successes == 4)
        let offer = try #require(try await market.offer(id: earlyBird))
        #expect(offer.quantityReserved == offer.quantityTotal)
        #expect(try await market.reservations().count == 4)
    }

    @Test func changeQuantityMovesStock() async throws {
        let market = try await stores().marketplace
        let r = try await market.reserve(offerID: earlyBird, quantity: 1, at: TestEnv.sep(24, 7))
        #expect(try await market.changeQuantity(reservationID: r.id, to: 3, at: TestEnv.sep(24, 8)).quantity == 3)
        #expect(try await market.offer(id: earlyBird)?.quantityLeft == 1)
        #expect(try await market.changeQuantity(reservationID: r.id, to: 1, at: TestEnv.sep(24, 8)).quantity == 1)
        #expect(try await market.offer(id: earlyBird)?.quantityLeft == 3)
        await #expect(throws: ReservationError.invalidQuantity) {
            try await market.changeQuantity(reservationID: r.id, to: 4, at: TestEnv.sep(24, 8))
        }
        await #expect(throws: ReservationError.changeClosed) {
            try await market.changeQuantity(reservationID: r.id, to: 2, at: TestEnv.sep(24, 9, 50))
        }
        await #expect(throws: ReservationError.reservationNotFound) {
            try await market.changeQuantity(reservationID: UUID(), to: 2, at: TestEnv.sep(24, 8))
        }
    }

    @Test func cancelReturnsStock() async throws {
        let market = try await stores().marketplace
        let r = try await market.reserve(offerID: earlyBird, quantity: 3, at: TestEnv.sep(24, 7))
        #expect(try await market.offer(id: earlyBird)?.quantityLeft == 1)
        let cancelled = try await market.cancel(reservationID: r.id, reason: .plansChanged, at: TestEnv.sep(24, 8))
        #expect(cancelled.cancelReason == .plansChanged)
        #expect(cancelled.cancelledAt == TestEnv.sep(24, 8))
        #expect(try await market.offer(id: earlyBird)?.quantityLeft == 4)
        await #expect(throws: ReservationError.changeClosed) {
            try await market.cancel(reservationID: r.id, reason: nil, at: TestEnv.sep(24, 8))
        }
    }

    @Test func missingOfferFailsGracefully() async throws {
        let market = try await stores().marketplace
        let r = try await market.reserve(offerID: earlyBird, quantity: 1, at: TestEnv.sep(24, 7))
        try await market.deleteOffer(id: earlyBird)
        await #expect(throws: ReservationError.offerNoLongerExists) {
            try await market.changeQuantity(reservationID: r.id, to: 2, at: TestEnv.sep(24, 8))
        }
        await #expect(throws: ReservationError.offerNoLongerExists) {
            try await market.cancel(reservationID: r.id, reason: nil, at: TestEnv.sep(24, 8))
        }
        // The order itself is intact and can still be collected from its snapshot.
        #expect(try await market.markCollected(reservationID: r.id, at: TestEnv.sep(24, 8)).collectedAt != nil)
    }

    @Test func collectOnlyDuringTheWindow() async throws {
        let market = try await stores().marketplace
        let r = try await market.reserve(offerID: earlyBird, quantity: 1, at: TestEnv.sep(24, 7))
        await #expect(throws: ReservationError.notReadyForPickup) {
            try await market.markCollected(reservationID: r.id, at: TestEnv.sep(24, 7, 15))
        }
        let collected = try await market.markCollected(reservationID: r.id, at: TestEnv.sep(24, 8))
        #expect(collected.collectedAt == TestEnv.sep(24, 8))
        await #expect(throws: ReservationError.notReadyForPickup) {
            try await market.markCollected(reservationID: r.id, at: TestEnv.sep(24, 8, 5))
        }
    }

    @Test func reviewUpdatesRestaurantRatingInTheSameSave() async throws {
        let market = try await stores().marketplace
        let r = try await market.reserve(offerID: earlyBird, quantity: 1, at: TestEnv.sep(24, 7))
        _ = try await market.markCollected(reservationID: r.id, at: TestEnv.sep(24, 8))

        let review = Review(overall: 5, quality: 4, tags: [.fresh], comment: "Great", submittedAt: .distantPast)
        let restaurant = try #require(
            try await market.submitReview(review, for: r.id, at: TestEnv.sep(24, 9)))
        #expect(restaurant.reviewCount == 213)
        #expect(abs(restaurant.rating - (4.8 * 212 + 5) / 213) < 0.000_001)
        #expect(try await market.restaurant(id: "rst_early_bird_bakehouse") == restaurant)

        let saved = try #require(try await market.reservation(id: r.id)?.review)
        #expect(saved.tags == [.fresh] && saved.comment == "Great")
        #expect(saved.submittedAt == TestEnv.sep(24, 9))

        await #expect(throws: ReviewError.notEligible) {
            try await market.submitReview(review, for: r.id, at: TestEnv.sep(24, 10))
        }
    }

    @Test func reviewValidation() async throws {
        let market = try await stores().marketplace
        let r = try await market.reserve(offerID: earlyBird, quantity: 1, at: TestEnv.sep(24, 7))
        await #expect(throws: ReviewError.notEligible) {
            try await market.submitReview(
                Review(overall: 5, submittedAt: .distantPast), for: r.id, at: TestEnv.sep(24, 8))
        }
        _ = try await market.markCollected(reservationID: r.id, at: TestEnv.sep(24, 8))
        await #expect(throws: ReviewError.invalidRating) {
            try await market.submitReview(
                Review(overall: 0, submittedAt: .distantPast), for: r.id, at: TestEnv.sep(24, 9))
        }
        #expect(try await market.restaurant(id: "rst_early_bird_bakehouse")?.reviewCount == 212)
    }

    @Test func mutationsEmitChanges() async throws {
        let market = try await stores().marketplace
        var changes = market.changes().makeAsyncIterator()
        _ = try await market.reserve(offerID: earlyBird, quantity: 1, at: TestEnv.sep(24, 7))
        #expect(await changes.next() == .stockChanged(offerID: earlyBird))
        #expect(await changes.next() == .reservationsChanged)
    }
}
