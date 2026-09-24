//
//  PickupAndManageTests.swift
//  CustomerFeaturesTests
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Pickup")
struct PickupModelTests {
    static let breakfast = Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599, total: 5)
    static let tomorrow = Fixture.offer("breakfast", day: 25, start: (7, 30), end: (10, 0), price: 599)

    func pickup(
        _ reservation: Reservation, at now: Date, flags: FeatureFlags = Fixture.flags()
    ) async -> (PickupModel, Harness) {
        let harness = Harness(now: now, offers: [Self.breakfast, Self.tomorrow], flags: flags)
        harness.marketplace.add(reservation)
        let model = PickupModel(
            reservationID: reservation.id, origin: ResolvedLocation(coordinate: Fixture.licCenter, source: .device),
            dependencies: harness.dependencies)
        await model.load()
        return (model, harness)
    }

    @Test func upcomingTomorrow() async {
        let (model, _) = await pickup(Fixture.reservation(for: Self.tomorrow), at: Fixture.sep(24, 20, 30))
        #expect(model.header?.title == "Pickup opens tomorrow at 7:30 AM")
        #expect(model.header?.subtitle == "Your bag is held until 10:00 AM")
        #expect(model.confirmFromText == "You can confirm pickup from tomorrow at 7:30 AM")
        #expect(model.code == "QW3E")
        #expect(model.pickupInstructions == "Ask at the counter.")
        #expect(model.summary.map(\.value)[1] == "Pick up tomorrow, Fri Sep 25, 7:30–10:00 AM")
        #expect(model.canManage)
    }

    @Test func readyNowThenCollect() async {
        let (model, _) = await pickup(Fixture.reservation(for: Self.breakfast, quantity: 2), at: Fixture.sep(24, 8))
        #expect(model.status == .readyNow)
        #expect(model.header?.title == "Ready for pickup")
        #expect(model.header?.subtitle == "Open until 10:00 AM")
        await model.collect()
        #expect(model.status == .collected)
        #expect(model.header?.title == "Enjoy your breakfast!")
        #expect(model.canReview)
        #expect(model.impactText == "You saved $23.96 and about 5.0 kg of CO₂e.")
        model.rate(stars: 4)
        #expect(model.rateRequest?.stars == 4)
    }

    @Test func readySubtitleCountsDownInTheLastHour() async {
        let (model, _) = await pickup(Fixture.reservation(for: Self.breakfast), at: Fixture.sep(24, 9, 40))
        #expect(model.header?.subtitle == "Ends in 20 min · until 10:00 AM")
    }

    @Test func collectOutsideTheWindowShowsAnAlert() async {
        let (model, _) = await pickup(Fixture.reservation(for: Self.breakfast), at: Fixture.sep(24, 7))
        await model.collect()
        #expect(model.collectFailed)
        #expect(model.status == .upcoming)
    }

    @Test func changesCloseTenMinutesBeforeTheEnd() async {
        let (model, _) = await pickup(Fixture.reservation(for: Self.breakfast), at: Fixture.sep(24, 9, 55))
        #expect(!model.canManage)
        #expect(model.changesClosedText == "Changes closed at 9:50 AM. The store is getting your bag ready.")
    }

    @Test func manageOrderFlagOffHidesTheEntryPoint() async {
        let (model, _) = await pickup(
            Fixture.reservation(for: Self.breakfast), at: Fixture.sep(24, 7), flags: Fixture.flags(manageOrder: false))
        #expect(!model.canManage)
        #expect(model.changesClosedText == nil)
    }

    @Test func flagsHideImpactAndRating() async {
        let collected = Fixture.reservation(for: Self.breakfast, collectedAt: Fixture.sep(24, 8))
        let (model, _) = await pickup(
            collected, at: Fixture.sep(24, 9), flags: Fixture.flags(reviews: false, impact: false))
        #expect(model.impactText == nil)
        #expect(!model.canReview)
    }

    @Test func missedAndCancelledHeaders() async {
        let (missed, _) = await pickup(Fixture.reservation(for: Self.breakfast), at: Fixture.sep(24, 10, 30))
        #expect(missed.header?.title == "Pickup window ended")
        #expect(missed.confirmFromText == nil)
        let cancelled = Fixture.reservation(for: Self.breakfast, cancelledAt: Fixture.sep(24, 7))
        let (model, _) = await pickup(cancelled, at: Fixture.sep(24, 8))
        #expect(model.header?.title == "Order cancelled")
        #expect(!model.isActive)
    }

    @Test func directionsAndNotFound() async throws {
        let (model, _) = await pickup(Fixture.reservation(for: Self.breakfast), at: Fixture.sep(24, 7))
        let url = try #require(model.directionsURL)
        #expect(url.absoluteString.contains("daddr=40.7443,-73.9532"))
        #expect(model.addressLine == "Vernon Blvd & 48th Ave, Long Island City · 0.2 mi")

        let harness = Harness(now: Fixture.sep(24, 7), offers: [])
        let missing = PickupModel(
            reservationID: UUID(), origin: ResolvedLocation(coordinate: Fixture.licCenter, source: .device),
            dependencies: harness.dependencies)
        await missing.load()
        #expect(missing.state == .notFound)
    }
}

@MainActor
@Suite("Manage order")
struct ManageOrderModelTests {
    static let offer = Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599, total: 5, reserved: 1)

    func manage(quantity: Int = 2, at now: Date = Fixture.sep(24, 8)) async -> (ManageOrderModel, Harness) {
        let harness = Harness(now: now, offers: [Self.offer])
        let reservation = harness.marketplace.add(Fixture.reservation(for: Self.offer, quantity: quantity))
        let model = ManageOrderModel(reservationID: reservation.id, dependencies: harness.dependencies)
        await model.load()
        return (model, harness)
    }

    @Test func limitsAndCopy() async {
        let (model, _) = await manage()  // 5 total, 1 simulated + 2 ours → 2 left
        #expect(model.quantity == 2)
        #expect(model.maxQuantity == 3)
        #expect(!model.canSave)
        #expect(model.quantityFooter == "You can hold up to 3 bags. Near Café has 1 more available.")
        #expect(model.deadlineNotice.title == "Free changes until 9:50 AM")
        #expect(model.deadlineNotice.detail == "10 minutes before pickup ends")
        #expect(model.pickupText == "Today · until 10:00 AM")
    }

    @Test func minutesLeftUnderAnHour() async {
        let (model, _) = await manage(at: Fixture.sep(24, 9, 25))
        #expect(model.deadlineNotice.detail == "25 min left")
    }

    @Test func saveChangesStock() async {
        let (model, harness) = await manage()
        model.quantity = 3
        #expect(model.canSave)
        #expect(model.newTotal == Money(cents: 1797))
        await model.saveQuantity()
        #expect(model.finished)
        #expect(harness.marketplace.offerLeft(Self.offer.id) == 1)
    }

    @Test func cancelWithReasonReturnsStock() async throws {
        let (model, harness) = await manage()
        model.reason = .plansChanged
        #expect(model.cancelMessage == "Your bags go back on sale for other customers. You won't be charged.")
        await model.cancel()
        #expect(model.finished)
        #expect(harness.marketplace.offerLeft(Self.offer.id) == 4)
        #expect(try await harness.marketplace.reservations().first?.cancelReason == .plansChanged)
    }

    @Test func refusedChangesRaiseTheAlert() async {
        let (model, harness) = await manage()
        harness.marketplace.failNextReserve(with: ReservationError.changeClosed)
        await model.cancel()
        #expect(model.failed)
        #expect(!model.finished)
    }

    @Test func closedAfterTheDeadline() async {
        let (model, _) = await manage(at: Fixture.sep(24, 9, 51))
        #expect(!model.isOpen)
        #expect(model.deadlineNotice.title == "Changes closed at 9:50 AM")
    }
}
