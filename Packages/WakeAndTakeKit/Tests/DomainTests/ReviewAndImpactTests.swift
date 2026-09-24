//
//  ReviewAndImpactTests.swift
//  DomainTests
//

import Foundation
import Testing

@testable import Domain

@Suite("ReviewPolicy")
struct ReviewPolicyTests {
    let collectedAt = Fixtures.date(8, 0)

    @Test func onlyCollectedOrdersCanBeReviewed() {
        #expect(!ReviewPolicy.canReview(Fixtures.reservation(), at: Fixtures.date(9, 0)))
        let cancelled = Fixtures.reservation(cancelledAt: Fixtures.date(7, 0))
        #expect(!ReviewPolicy.canReview(cancelled, at: Fixtures.date(9, 0)))
        #expect(ReviewPolicy.canReview(Fixtures.reservation(collectedAt: collectedAt), at: Fixtures.date(9, 0)))
    }

    @Test func reviewWindowIs48Hours() {
        let r = Fixtures.reservation(collectedAt: collectedAt)
        let justBefore = collectedAt.addingTimeInterval(48 * 3600 - 1)
        let atLimit = collectedAt.addingTimeInterval(48 * 3600)
        #expect(ReviewPolicy.canReview(r, at: justBefore))
        #expect(!ReviewPolicy.canReview(r, at: atLimit))
    }

    @Test func onlyOneReviewPerOrder() {
        let reviewed = Fixtures.reservation(
            collectedAt: collectedAt,
            review: Review(overall: 5, submittedAt: Fixtures.date(9, 0))
        )
        #expect(!ReviewPolicy.canReview(reviewed, at: Fixtures.date(10, 0)))
        #expect(throws: ReviewError.notEligible) {
            try ReviewPolicy.validate(
                Review(overall: 4, submittedAt: Fixtures.date(10, 0)), for: reviewed,
                at: Fixtures.date(10, 0))
        }
    }

    @Test(arguments: [0, 6, -1])
    func overallMustBeOneToFive(overall: Int) {
        let r = Fixtures.reservation(collectedAt: collectedAt)
        #expect(throws: ReviewError.invalidRating) {
            try ReviewPolicy.validate(
                Review(overall: overall, submittedAt: Fixtures.date(9, 0)), for: r,
                at: Fixtures.date(9, 0))
        }
    }

    @Test func detailRatingsAreOptional() {
        #expect(ReviewPolicy.isValid(Review(overall: 3, submittedAt: collectedAt)))
        #expect(ReviewPolicy.isValid(Review(overall: 3, quality: 5, value: 1, pickup: 0, submittedAt: collectedAt)))
        #expect(!ReviewPolicy.isValid(Review(overall: 3, quality: 6, submittedAt: collectedAt)))
    }

    @Test func ratingFoldsIntoRunningAverage() {
        let folded = ReviewPolicy.foldedRating(rating: 4.0, reviewCount: 3, adding: 5)
        #expect(folded.reviewCount == 4)
        #expect(folded.rating == 4.25)
        let first = ReviewPolicy.foldedRating(rating: 0, reviewCount: 0, adding: 2)
        #expect(first.rating == 2 && first.reviewCount == 1)
    }
}

@Suite("ImpactCalculator")
struct ImpactCalculatorTests {
    @Test func countsCollectedReservationsOnly() {
        let reservations = [
            Fixtures.reservation(quantity: 2, price: 599, value: 1800, collectedAt: Fixtures.date(8, 0)),
            Fixtures.reservation(quantity: 1, price: 450, value: 1200, collectedAt: Fixtures.date(8, 30)),
            Fixtures.reservation(quantity: 3, cancelledAt: Fixtures.date(7, 0)),
            Fixtures.reservation(quantity: 1),
        ]
        let impact = ImpactCalculator.impact(of: reservations)
        #expect(impact.bagsRescued == 3)
        #expect(impact.moneySaved == Money(cents: 2 * 1201 + 750))
        #expect(impact.co2eAvoidedKg == 7.5)
    }

    @Test func emptyIsZero() {
        #expect(ImpactCalculator.impact(of: []) == Impact())
        #expect(ImpactCalculator.co2e(forBags: 4) == 10)
    }
}
