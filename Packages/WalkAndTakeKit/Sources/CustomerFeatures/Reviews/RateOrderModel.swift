//
//  RateOrderModel.swift
//  WalkAndTakeKit
//
//  User Journey 7: after picking up, a customer rates their bag.
//  Ratings feed the store scores shown in Discover.
//

import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class RateOrderModel {
    public enum State: Equatable {
        case loading, rating, submitted, notFound
    }

    public private(set) var state: State = .loading
    public var overall: Int
    public var quality = 0
    public var value = 0
    public var pickup = 0
    public var tags: Set<ReviewTag> = []
    public var comment = ""
    /// The order can't be rated (already rated or past 48 h); the view explains and closes.
    public var failed = false
    public private(set) var isSubmitting = false

    private(set) var restaurantName = ""
    private var updatedRestaurant: Restaurant?
    private let reservationID: UUID
    private let dependencies: CustomerDependencies

    public init(reservationID: UUID, initialStars: Int, dependencies: CustomerDependencies) {
        self.reservationID = reservationID
        self.dependencies = dependencies
        overall = initialStars
    }

    public func load() async {
        guard let reservation = try? await dependencies.reservations.reservation(id: reservationID) else {
            state = .notFound
            return
        }
        restaurantName = reservation.snapshot.restaurantName
        state = .rating
    }

    public func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let now = dependencies.clock.now
        let review = Review(
            overall: overall, quality: quality, value: value, pickup: pickup, tags: tags,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines), submittedAt: now)
        do {
            updatedRestaurant = try await dependencies.reviews.submitReview(review, for: reservationID, at: now)
            state = .submitted
        } catch {
            failed = true
        }
    }

    // MARK: - Output

    public var canSubmit: Bool { (1...5).contains(overall) && !isSubmitting }

    public var title: String { "How was your bag from \(restaurantName)?" }

    public var overallCaption: String {
        switch overall {
        case 1: "Not great"
        case 2: "Could be better"
        case 3: "It was OK"
        case 4: "Really good"
        case 5: "Loved it!"
        default: "Tap a star to rate"
        }
    }

    public var sharingFooter: String {
        "Your rating is shared with \(restaurantName) and counts toward its score in Discover."
    }

    /// "Crane & Kettle is now rated 4.7 from 144 ratings."
    public var thanksText: String? {
        guard let restaurant = updatedRestaurant else { return nil }
        return String(
            format: "%@ is now rated %.1f from %d ratings.", restaurant.name, restaurant.rating, restaurant.reviewCount)
    }
}
