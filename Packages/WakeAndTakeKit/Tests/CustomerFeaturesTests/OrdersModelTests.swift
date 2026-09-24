//
//  OrdersModelTests.swift
//  CustomerFeaturesTests
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Orders")
struct OrdersModelTests {
    static let breakfast = Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599)
    static let dinner = Fixture.offer("dinner", start: (21, 0), end: (23, 59), category: .meal, price: 899)
    static let tomorrow = Fixture.offer("breakfast", day: 25, start: (7, 30), end: (10, 0), price: 599)

    func orders(at now: Date, flags: FeatureFlags = Fixture.flags(), _ seed: (FakeMarketplace) -> Void)
        async -> (OrdersModel, Harness)
    {
        let harness = Harness(
            now: now, offers: [Self.breakfast, Self.dinner, Self.tomorrow], flags: flags)
        seed(harness.marketplace)
        let model = OrdersModel(dependencies: harness.dependencies)
        await model.load()
        return (model, harness)
    }

    @Test func emptyState() async {
        let (model, _) = await orders(at: Fixture.sep(24, 8)) { _ in }
        #expect(model.state == .empty)
        #expect(model.activeCount == 0)
    }

    @Test func activeOrdersAreGroupedByPickupDay() async throws {
        let (model, _) = await orders(at: Fixture.sep(24, 20, 30)) {
            $0.add(Fixture.reservation(for: Self.tomorrow, reservedAt: Fixture.sep(24, 20, 10)))
            $0.add(Fixture.reservation(for: Self.dinner, quantity: 2))
        }
        #expect(model.state == .loaded)
        #expect(model.activeGroups.map(\.title) == ["Tonight", "Tomorrow"])
        #expect(model.activeGroups.map(\.day) == [.tonight, .tomorrow])
        let tomorrowRow = try #require(model.activeGroups.last?.rows.first)
        #expect(tomorrowRow.statusText == "Opens tomorrow at 7:30 AM")
        #expect(tomorrowRow.tone == .upcoming)
        #expect(model.activeGroups.first?.rows.first?.bagsText == "2 × dinner bag")
        #expect(model.activeCount == 2)
    }

    @Test func rowStatusCopy() async {
        let (model, _) = await orders(at: Fixture.sep(24, 9, 40)) {
            $0.add(Fixture.reservation(for: Self.breakfast))
        }
        let row = model.activeGroups.first?.rows.first
        #expect(row?.statusText == "Ready now · Ends in 20 min")
        #expect(row?.tone == .readyNow)
    }

    @Test func pastOrdersAndImpact() async throws {
        let (model, _) = await orders(at: Fixture.sep(24, 11)) {
            $0.add(Fixture.reservation(for: Self.breakfast, quantity: 2, collectedAt: Fixture.sep(24, 8)))
            $0.add(Fixture.reservation(for: Self.breakfast, cancelledAt: Fixture.sep(24, 7)))
        }
        #expect(model.activeGroups.isEmpty)
        #expect(model.past.map(\.statusText) == ["Cancelled", "Picked up"])  // newest first
        let collected = try #require(model.past.last)
        #expect(collected.showsRatePrompt)
        #expect(model.impact.bagsRescued == 2)
        #expect(model.impact.moneySaved == Money(cents: 2 * (1797 - 599)))
    }

    @Test func missedOrdersArePast() async {
        let (model, _) = await orders(at: Fixture.sep(24, 10, 5)) {
            $0.add(Fixture.reservation(for: Self.breakfast))
        }
        #expect(model.past.first?.statusText == "Missed pickup")
        #expect(model.activeCount == 0)
    }

    @Test func reviewsFlagOffHidesRatingsAndPrompts() async {
        let review = Review(overall: 4, submittedAt: Fixture.sep(24, 9))
        let (model, _) = await orders(at: Fixture.sep(24, 11), flags: Fixture.flags(reviews: false)) {
            $0.add(Fixture.reservation(for: Self.breakfast, collectedAt: Fixture.sep(24, 8), review: review))
            $0.add(Fixture.reservation(for: Self.breakfast, collectedAt: Fixture.sep(24, 8)))
        }
        #expect(model.past.allSatisfy { $0.rating == nil && !$0.showsRatePrompt })
    }

    @Test func badgeFollowsReservationChanges() async throws {
        let harness = Harness(now: Fixture.sep(24, 8), offers: [Self.breakfast])
        let model = OrdersModel(dependencies: harness.dependencies)
        let task = Task { await model.run() }
        defer { task.cancel() }
        #expect(await eventually { model.state == .empty })
        _ = try await harness.marketplace.reserve(offerID: Self.breakfast.id, quantity: 1, at: Fixture.sep(24, 8))
        #expect(await eventually { model.activeCount == 1 })
    }

    @Test func failedLoadThenRetry() async {
        let harness = Harness(now: Fixture.sep(24, 8), offers: [])
        harness.marketplace.failReads(true)
        let model = OrdersModel(dependencies: harness.dependencies)
        await model.load()
        guard case .failed = model.state else {
            Issue.record("expected failed")
            return
        }
        harness.marketplace.failReads(false)
        await model.retry()
        #expect(model.state == .empty)
    }
}
