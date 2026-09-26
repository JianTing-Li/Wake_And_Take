//
//  PickupModel.swift
//  WalkAndTakeKit
//
//  Everything here reads the reservation's snapshot, never the live offer.
//

import DesignSystem
import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class PickupModel {
    public enum State: Equatable {
        case loading, loaded, notFound
        case failed(String)
    }

    public struct Header: Hashable, Sendable {
        public let symbol: String
        public let tone: PickupStatusPill.Tone
        public let title: String
        public let subtitle: String
    }

    public private(set) var state: State = .loading
    public var collectFailed = false
    /// Stars tapped on the rating card; presents the rating sheet.
    public var rateRequest: RateRequest?

    private(set) var reservation: Reservation?
    private var now: Date
    private let reservationID: UUID
    private let origin: ResolvedLocation
    private let dependencies: CustomerDependencies

    public init(reservationID: UUID, origin: ResolvedLocation, dependencies: CustomerDependencies) {
        self.reservationID = reservationID
        self.origin = origin
        self.dependencies = dependencies
        now = dependencies.clock.now
    }

    public var flags: FeatureFlags { dependencies.flags }
    private var calendar: Calendar { NYCalendar.calendar }

    // MARK: - Lifecycle

    public func run() async {
        await load()
        let changes = dependencies.reservations.changes()
        let clockChanges = dependencies.clock.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in changes { await self.load() } }
            group.addTask { for await _ in clockChanges { await self.load() } }
            group.addTask {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    await self.load()
                }
            }
        }
    }

    public func load() async {
        do {
            reservation = try await dependencies.reservations.reservation(id: reservationID)
            now = dependencies.clock.now
            state = reservation == nil ? .notFound : .loaded
        } catch {
            if state == .loading { state = .failed("Couldn't load this order. Please try again.") }
        }
    }

    // MARK: - Actions

    /// Confirms pickup at the counter (after the swipe).
    public func collect() async {
        do {
            reservation = try await dependencies.reservations.markCollected(
                reservationID: reservationID, at: dependencies.clock.now)
            now = dependencies.clock.now
        } catch {
            collectFailed = true
        }
    }

    public func rate(stars: Int) {
        rateRequest = RateRequest(reservationID: reservationID, stars: stars)
    }

    // MARK: - Output

    public var status: ReservationPolicy.Status? {
        reservation.map { ReservationPolicy.status(of: $0, at: now) }
    }

    public var isActive: Bool { status == .upcoming || status == .readyNow }
    public var restaurantName: String { reservation?.snapshot.restaurantName ?? "" }
    public var code: String { reservation?.confirmationCode ?? "" }
    public var pickupInstructions: String { reservation?.snapshot.pickupInstructions ?? "" }

    public var header: Header? {
        guard let reservation, let status else { return nil }
        let window = reservation.snapshot.pickupWindow
        let countdown = PickupDayFormatter.countdown(window, now: now, calendar: calendar)
        let end = time(window.end)
        return switch status {
        case .readyNow:
            Header(
                symbol: "bag.fill", tone: .readyNow, title: "Ready for pickup",
                subtitle: countdown.hasPrefix("Ends in") ? "\(countdown) · until \(end)" : "Open until \(end)")
        case .upcoming:
            Header(
                symbol: "clock.fill", tone: .upcoming,
                title: countdown.replacingOccurrences(of: "Opens", with: "Pickup opens"),
                subtitle: "Your bag is held until \(end)")
        case .collected:
            Header(
                symbol: "checkmark.circle.fill", tone: .collected,
                title: reservation.snapshot.category == .breakfast ? "Enjoy your breakfast!" : "Enjoy your food!",
                subtitle: "Picked up at \(time(reservation.collectedAt ?? now))")
        case .missed:
            Header(
                symbol: "xmark.circle.fill", tone: .inactive, title: "Pickup window ended",
                subtitle: "This order wasn't collected before \(end).")
        case .cancelled:
            Header(
                symbol: "xmark.circle.fill", tone: .inactive, title: "Order cancelled",
                subtitle: "Cancelled at \(time(reservation.cancelledAt ?? now)). You won't be charged, "
                    + "and your bag is back on sale for someone else.")
        }
    }

    /// Show "Change or cancel order" (manage flag on, before the deadline).
    public var canManage: Bool {
        guard flags.manageOrder, let reservation else { return false }
        return ReservationPolicy.canChange(reservation, at: now)
    }

    /// Shown instead of the manage link once changes close.
    public var changesClosedText: String? {
        guard flags.manageOrder, isActive, !canManage, let reservation else { return nil }
        let deadline = time(ReservationPolicy.changeDeadline(for: reservation))
        return "Changes closed at \(deadline). The store is getting your bag ready."
    }

    /// Bottom bar for an upcoming order: "You can confirm pickup from tomorrow at 7:30 AM".
    public var confirmFromText: String? {
        guard status == .upcoming, let reservation else { return nil }
        let window = reservation.snapshot.pickupWindow
        let when = time(window.start)
        return switch PickupDayFormatter.day(of: window, now: now, calendar: calendar) {
        case .today, .tonight: "You can confirm pickup from \(when)"
        case .tomorrow: "You can confirm pickup from tomorrow at \(when)"
        case .other(let date): "You can confirm pickup from \(TimeText.shortDate(date, calendar: calendar)) at \(when)"
        }
    }

    /// "Vernon Blvd & 48th Ave, Long Island City · 0.2 mi"
    public var addressLine: String {
        guard let snapshot = reservation?.snapshot else { return "" }
        let miles = PreferenceMatcher.distanceMiles(to: snapshot.coordinate, from: origin)
        return String(format: "%@ · %.1f mi", snapshot.address.shortLine, miles)
    }

    /// Apple Maps walking/transit directions to the restaurant.
    public var directionsURL: URL? {
        guard let snapshot = reservation?.snapshot else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(snapshot.coordinate.latitude),\(snapshot.coordinate.longitude)"),
            URLQueryItem(name: "q", value: snapshot.restaurantName),
        ]
        return components?.url
    }

    public var review: Review? { flags.reviews ? reservation?.review : nil }

    public var canReview: Bool {
        guard flags.reviews, let reservation else { return false }
        return ReviewPolicy.canReview(reservation, at: now)
    }

    /// "You saved $12.51 and about 2.5 kg of CO₂e." (impact flag, collected only)
    public var impactText: String? {
        guard flags.impact, status == .collected, let reservation else { return nil }
        let kg = ImpactCalculator.co2e(forBags: reservation.quantity)
        return "You saved \(reservation.savings.usd) and about \(String(format: "%.1f", kg)) kg of CO₂e."
    }

    public var summary: [(label: String, value: String)] {
        guard let reservation else { return [] }
        return [
            ("Order", "\(reservation.quantity) × \(reservation.snapshot.bagName)"),
            ("Pickup", PickupDayFormatter.full(reservation.snapshot.pickupWindow, now: now, calendar: calendar)),
            ("Total", reservation.total.usd),
        ]
    }

    private func time(_ date: Date) -> String { TimeText.time(date, calendar: calendar) }
}

/// Opens the rating sheet with the stars already tapped.
public struct RateRequest: Identifiable, Hashable, Sendable {
    public var id: UUID { reservationID }
    public let reservationID: UUID
    public let stars: Int
}
