//
//  ManageOrderModel.swift
//  WakeAndTakeKit
//
//  User Journey 5: a customer's plans change, so they change how many
//  bags they're picking up or cancel the order before the deadline.
//

import DesignSystem
import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class ManageOrderModel {
    public enum State: Equatable {
        case loading, loaded, notFound
    }

    public private(set) var state: State = .loading
    public var quantity = 1
    public var reason: CancelReason?
    public var confirmingCancel = false
    /// Set when a change or cancel is refused; the view offers to leave.
    public var failed = false
    /// Set after a successful save or cancel; the view dismisses.
    public private(set) var finished = false

    private(set) var reservation: Reservation?
    private var offerQuantityLeft = 0
    private var now: Date
    private let reservationID: UUID
    private let dependencies: CustomerDependencies

    public init(reservationID: UUID, dependencies: CustomerDependencies) {
        self.reservationID = reservationID
        self.dependencies = dependencies
        now = dependencies.clock.now
    }

    private var calendar: Calendar { NYCalendar.calendar }

    // MARK: - Lifecycle

    public func run() async {
        await load(resettingQuantity: true)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(15))
            await load(resettingQuantity: false)
        }
    }

    public func load(resettingQuantity: Bool = true) async {
        now = dependencies.clock.now
        guard let reservation = try? await dependencies.reservations.reservation(id: reservationID) else {
            state = .notFound
            return
        }
        self.reservation = reservation
        let offer = try? await dependencies.offers.offer(id: reservation.snapshot.offerID)
        offerQuantityLeft = offer?.quantityLeft ?? 0
        if resettingQuantity { quantity = reservation.quantity }
        quantity = min(max(quantity, 1), maxQuantity)
        state = .loaded
    }

    // MARK: - Actions

    public func saveQuantity() async {
        await perform {
            try await dependencies.reservations.changeQuantity(
                reservationID: reservationID, to: quantity, at: dependencies.clock.now)
        }
    }

    public func cancel() async {
        await perform {
            try await dependencies.reservations.cancel(
                reservationID: reservationID, reason: reason, at: dependencies.clock.now)
        }
    }

    private func perform(_ action: () async throws -> Reservation) async {
        do {
            reservation = try await action()
            finished = true
        } catch {
            failed = true
        }
    }

    // MARK: - Output

    public var isOpen: Bool {
        reservation.map { ReservationPolicy.canChange($0, at: now) } ?? false
    }

    /// 1…min(3, what you hold + what the store has left).
    public var maxQuantity: Int {
        reservation.map { ReservationPolicy.maxQuantity(forChanging: $0, offerQuantityLeft: offerQuantityLeft) } ?? 1
    }

    public var canSave: Bool { reservation.map { quantity != $0.quantity } ?? false }
    public var restaurantName: String { reservation?.snapshot.restaurantName ?? "" }
    public var orderText: String {
        reservation.map { "\($0.quantity) × \($0.snapshot.bagName)" } ?? ""
    }

    public var pickupText: String {
        reservation.map { PickupDayFormatter.short($0.snapshot.pickupWindow, now: now, calendar: calendar) } ?? ""
    }

    public var newTotal: Money { (reservation?.snapshot.unitPrice ?? .zero) * quantity }

    /// ("Free changes until 9:50 AM", "25 min left") or ("Changes closed at 9:50 AM", "…").
    public var deadlineNotice: (title: String, detail: String) {
        guard let reservation else { return ("", "") }
        let deadline = ReservationPolicy.changeDeadline(for: reservation)
        let time = TimeText.time(deadline, calendar: calendar)
        guard isOpen else { return ("Changes closed at \(time)", "The store is getting your bag ready.") }
        let minutes = max(1, Int(deadline.timeIntervalSince(now) / 60))
        return ("Free changes until \(time)", minutes < 60 ? "\(minutes) min left" : "10 minutes before pickup ends")
    }

    public var quantityFooter: String {
        guard let reservation else { return "" }
        let name = reservation.snapshot.restaurantName
        return maxQuantity > reservation.quantity
            ? "You can hold up to \(maxQuantity) bags. \(name) has \(maxQuantity - reservation.quantity) more available."
            : "\(name) has no more bags available, but you can reduce your order."
    }

    public var cancelMessage: String {
        let bags = reservation?.quantity == 1 ? "bag goes" : "bags go"
        return "Your \(bags) back on sale for other customers. You won't be charged."
    }
}
