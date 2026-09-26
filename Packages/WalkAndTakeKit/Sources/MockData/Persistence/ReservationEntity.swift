//
//  ReservationEntity.swift
//  WalkAndTakeKit
//
//  The offer snapshot and the (optional) review are flattened into one row.
//

import Domain
import Foundation
import SwiftData

@Model
final class ReservationEntity {
    #Unique<ReservationEntity>([\.id])

    var id: UUID
    var confirmationCode: String
    var quantity: Int
    var reservedAt: Date
    var collectedAt: Date?
    var cancelledAt: Date?
    var cancelReasonRaw: String?

    // Snapshot
    var offerID: String
    var restaurantID: String
    var restaurantName: String
    var street: String
    var crossStreet: String
    var neighborhood: String
    var borough: String
    var zip: String
    var latitude: Double
    var longitude: Double
    var pickupInstructions: String
    var bagName: String
    var categoryRaw: String
    var summary: String
    var unitPriceCents: Int
    var estimatedValueCents: Int
    var pickupStart: Date
    var pickupEnd: Date

    // Review
    var reviewOverall: Int?
    var reviewQuality: Int?
    var reviewValue: Int?
    var reviewPickup: Int?
    var reviewTagsRaw: [String]?
    var reviewComment: String?
    var reviewSubmittedAt: Date?

    init(_ reservation: Reservation) {
        let s = reservation.snapshot
        id = reservation.id
        confirmationCode = reservation.confirmationCode
        quantity = reservation.quantity
        reservedAt = reservation.reservedAt
        offerID = s.offerID
        restaurantID = s.restaurantID
        restaurantName = s.restaurantName
        street = s.address.street
        crossStreet = s.address.crossStreet
        neighborhood = s.address.neighborhood
        borough = s.address.borough
        zip = s.address.zip
        latitude = s.coordinate.latitude
        longitude = s.coordinate.longitude
        pickupInstructions = s.pickupInstructions
        bagName = s.bagName
        categoryRaw = s.category.rawValue
        summary = s.summary
        unitPriceCents = s.unitPrice.cents
        estimatedValueCents = s.estimatedValue.cents
        pickupStart = s.pickupWindow.start
        pickupEnd = s.pickupWindow.end
        apply(reservation)
    }

    /// Copies the mutable fields (status, quantity, review).
    func apply(_ reservation: Reservation) {
        quantity = reservation.quantity
        collectedAt = reservation.collectedAt
        cancelledAt = reservation.cancelledAt
        cancelReasonRaw = reservation.cancelReason?.rawValue
        let review = reservation.review
        reviewOverall = review?.overall
        reviewQuality = review?.quality
        reviewValue = review?.value
        reviewPickup = review?.pickup
        reviewTagsRaw = review.map { $0.tags.map(\.rawValue).sorted() }
        reviewComment = review?.comment
        reviewSubmittedAt = review?.submittedAt
    }

    var domain: Reservation {
        Reservation(
            id: id,
            confirmationCode: confirmationCode,
            quantity: quantity,
            snapshot: OfferSnapshot(
                offerID: offerID,
                restaurantID: restaurantID,
                restaurantName: restaurantName,
                address: Restaurant.Address(
                    street: street,
                    crossStreet: crossStreet,
                    neighborhood: neighborhood,
                    borough: borough,
                    zip: zip
                ),
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                pickupInstructions: pickupInstructions,
                bagName: bagName,
                category: FoodCategory(rawValue: categoryRaw) ?? .meal,
                summary: summary,
                unitPrice: Money(cents: unitPriceCents),
                estimatedValue: Money(cents: estimatedValueCents),
                pickupWindow: PickupWindow(start: pickupStart, end: pickupEnd)
            ),
            reservedAt: reservedAt,
            collectedAt: collectedAt,
            cancelledAt: cancelledAt,
            cancelReason: cancelReasonRaw.flatMap(CancelReason.init(rawValue:)),
            review: review
        )
    }

    private var review: Review? {
        guard let overall = reviewOverall, let submittedAt = reviewSubmittedAt else { return nil }
        return Review(
            overall: overall,
            quality: reviewQuality ?? 0,
            value: reviewValue ?? 0,
            pickup: reviewPickup ?? 0,
            tags: Set((reviewTagsRaw ?? []).compactMap(ReviewTag.init(rawValue:))),
            comment: reviewComment ?? "",
            submittedAt: submittedAt
        )
    }
}
