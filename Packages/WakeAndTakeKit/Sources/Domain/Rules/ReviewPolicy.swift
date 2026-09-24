//
//  ReviewPolicy.swift
//  WakeAndTakeKit
//

import Foundation

public enum ReviewError: Error, Hashable, Sendable {
    /// Not collected, already reviewed, or the review window passed.
    case notEligible
    /// Overall outside 1–5, or a detail rating outside 0–5.
    case invalidRating
}

/// Picked-up orders can be rated once, for up to two days.
public enum ReviewPolicy {
    public static let reviewWindow: TimeInterval = 48 * 60 * 60
    public static let ratingRange = 1...5

    public static func canReview(_ reservation: Reservation, at now: Date) -> Bool {
        guard reservation.review == nil, let collectedAt = reservation.collectedAt else { return false }
        return now.timeIntervalSince(collectedAt) < reviewWindow
    }

    /// Overall is required (1–5); detail ratings are optional (0 = not rated).
    public static func isValid(_ review: Review) -> Bool {
        ratingRange.contains(review.overall)
            && [review.quality, review.value, review.pickup].allSatisfy { (0...5).contains($0) }
    }

    public static func validate(
        _ review: Review,
        for reservation: Reservation,
        at now: Date
    ) throws(ReviewError) {
        guard canReview(reservation, at: now) else { throw .notEligible }
        guard isValid(review) else { throw .invalidRating }
    }

    /// Folds a new overall rating into a restaurant's running average.
    public static func foldedRating(
        rating: Double,
        reviewCount: Int,
        adding overall: Int
    ) -> (rating: Double, reviewCount: Int) {
        let count = reviewCount + 1
        return ((rating * Double(reviewCount) + Double(overall)) / Double(count), count)
    }
}
