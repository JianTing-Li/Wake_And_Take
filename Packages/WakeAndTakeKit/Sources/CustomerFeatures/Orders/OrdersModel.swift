//
//  OrdersModel.swift
//  WakeAndTakeKit
//
//  User Journey 2: a customer picks up the order they reserved —
//  knows when and where to go, shows their code, and confirms pickup.
//

import Domain
import Foundation
import Observation
import Platform

@Observable
@MainActor
public final class OrdersModel {
    public enum State: Equatable {
        case loading, loaded, empty
        case failed(String)
    }

    /// Active orders for one pickup day ("Today", "Tonight", "Tomorrow", …).
    public struct DayGroup: Identifiable, Hashable, Sendable {
        public var id: String { title }
        public let title: String
        public let day: PickupDayFormatter.Day
        public let rows: [OrderRowContent]
    }

    public private(set) var state: State = .loading
    private var reservations: [Reservation] = []
    private var now: Date
    private let dependencies: CustomerDependencies

    public init(dependencies: CustomerDependencies) {
        self.dependencies = dependencies
        now = dependencies.clock.now
    }

    public var flags: FeatureFlags { dependencies.flags }

    // MARK: - Lifecycle

    /// Runs for the app's lifetime so the tab badge stays current.
    public func run() async {
        await load()
        let changes = dependencies.reservations.changes()
        let clockChanges = dependencies.clock.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in changes { await self.load() } }
            group.addTask { for await _ in clockChanges { await self.load() } }
            group.addTask {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    await self.load()
                }
            }
        }
    }

    public func load() async {
        do {
            reservations = try await dependencies.reservations.reservations()
            now = dependencies.clock.now
            state = reservations.isEmpty ? .empty : .loaded
        } catch {
            if state == .loading { state = .failed("Couldn't load your orders. Please try again.") }
        }
    }

    public func retry() async {
        state = .loading
        await load()
    }

    // MARK: - Output

    private var active: [Reservation] {
        reservations.filter { ReservationPolicy.isActive($0, at: now) }
    }

    /// For the Orders tab badge.
    public var activeCount: Int { active.count }

    public var impact: Impact { ImpactCalculator.impact(of: reservations) }

    /// Upcoming and ready orders, soonest first, grouped by pickup day.
    public var activeGroups: [DayGroup] {
        let calendar = NYCalendar.calendar
        let sorted = active.sorted {
            ($0.snapshot.pickupWindow.end, $0.reservedAt) < ($1.snapshot.pickupWindow.end, $1.reservedAt)
        }
        var order: [String] = []
        var days: [String: PickupDayFormatter.Day] = [:]
        var rows: [String: [OrderRowContent]] = [:]
        for reservation in sorted {
            let window = reservation.snapshot.pickupWindow
            let title = PickupDayFormatter.dayLabel(for: window, now: now, calendar: calendar)
            if rows[title] == nil {
                order.append(title)
                days[title] = PickupDayFormatter.day(of: window, now: now, calendar: calendar)
            }
            rows[title, default: []].append(OrderRowContent(reservation, now: now, flags: flags))
        }
        return order.map { DayGroup(title: $0, day: days[$0]!, rows: rows[$0]!) }
    }

    /// Collected, missed and cancelled orders, newest first.
    public var past: [OrderRowContent] {
        reservations
            .filter { !ReservationPolicy.isActive($0, at: now) }
            .map { OrderRowContent($0, now: now, flags: flags) }
    }
}
