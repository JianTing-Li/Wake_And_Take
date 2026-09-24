//
//  ReviewRepository.swift
//  WakeAndTakeKit
//

import Foundation

public protocol ReviewRepository: Sendable {
    /// Saves the review and folds it into the restaurant's rating in one transaction.
    /// Returns the restaurant with its new rating (nil if it no longer exists).
    /// Throws `ReviewError`.
    func submitReview(_ review: Review, for reservationID: UUID, at now: Date) async throws -> Restaurant?
}
