//
//  ReserveModel.swift
//  WalkAndTakeKit
//

import Domain
import Foundation
import Observation
import Platform

/// Quantity, the reserve call, and what happens after: an alert or a confirmation.
@Observable
@MainActor
public final class ReserveModel {
    public enum Alert: Hashable, Identifiable, Sendable {
        /// Sold out, window closed, or the quantity is no longer possible.
        case noLongerAvailable
        /// Tomorrow's bags can't be reserved before 20:00 New York.
        case notOpenYet
        /// Anything unexpected (e.g. storage).
        case failed

        public var id: Self { self }

        public var title: String {
            switch self {
            case .noLongerAvailable: "This bag is no longer available"
            case .notOpenYet: "Opens for reservations at 8 PM"
            case .failed: "Something went wrong"
            }
        }

        public var message: String {
            switch self {
            case .noLongerAvailable: "It sold out or the pickup window ended. Try another bag nearby."
            case .notOpenYet: "Tomorrow's bags can be reserved from 8 PM tonight."
            case .failed: "Your bag wasn't reserved. Please try again."
            }
        }
    }

    public var quantity = 1
    public private(set) var maxQuantity = 1
    public private(set) var isReserving = false
    public var alert: Alert?
    public var confirmation: ReservationConfirmation?

    private let offerID: String
    private let dependencies: CustomerDependencies

    init(offerID: String, dependencies: CustomerDependencies) {
        self.offerID = offerID
        self.dependencies = dependencies
    }

    /// Keeps the stepper within 1…min(3, bags left).
    func update(quantityLeft: Int) {
        maxQuantity = max(1, ReservationPolicy.maxQuantity(forNewReservationWithLeft: quantityLeft))
        quantity = min(max(quantity, 1), maxQuantity)
    }

    public func reserve() async {
        guard !isReserving else { return }
        isReserving = true
        defer { isReserving = false }
        let now = dependencies.clock.now
        do {
            let reservation = try await dependencies.reservations.reserve(
                offerID: offerID, quantity: quantity, at: now)
            quantity = 1
            confirmation = ReservationConfirmation(
                reservation: reservation, now: now, showsChangePolicy: dependencies.flags.manageOrder)
        } catch let error as ReservationError {
            alert = error == .notVisibleYet ? .notOpenYet : .noLongerAvailable
        } catch {
            alert = .failed
        }
    }
}
