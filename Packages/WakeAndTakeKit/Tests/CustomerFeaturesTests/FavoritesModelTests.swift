//
//  FavoritesModelTests.swift
//  CustomerFeaturesTests
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Favorites")
struct FavoritesModelTests {
    /// Near: open now (7:30–10:00, 2 left). Mid: opens at noon. Far: nothing visible.
    static let offers = [
        Fixture.offer("near-bfast", restaurant: "near", start: (7, 30), end: (10, 0), total: 5, reserved: 3),
        Fixture.offer("mid-lunch", restaurant: "mid", start: (12, 0), end: (14, 0), category: .meal),
        Fixture.offer("mid-tmrw", restaurant: "mid", day: 25, start: (7, 0), end: (9, 0)),
    ]

    func favorites(
        at now: Date = Fixture.sep(24, 8),
        _ favs: [FavoriteRestaurant] = ["far", "mid", "near"].map {
            FavoriteRestaurant(restaurantID: $0, alertsEnabled: false)
        },
        flags: FeatureFlags = Fixture.flags()
    ) async -> (FavoritesModel, Harness) {
        let harness = Harness(now: now, offers: Self.offers, favorites: favs, flags: flags)
        let model = FavoritesModel(dependencies: harness.dependencies, previewResetDelay: .milliseconds(20))
        await model.load()
        return (model, harness)
    }

    @Test func empty() async {
        let (model, _) = await favorites([])
        #expect(model.state == .empty)
    }

    @Test func rankedOpenNowThenUpcomingThenNone() async {
        let (model, _) = await favorites()
        #expect(model.rows.map(\.name) == ["Near Café", "Mid Deli", "Far Bistro"])
        #expect(model.rows[0].status == .availableNow("2 left · Ends at 10:00 AM"))
        #expect(model.rows[1].status == .upcoming("Opens at 12:00 PM"))
        #expect(model.rows[2].status == .none)
        #expect(model.rows.map(\.nextOfferID) == ["near-bfast-2026-09-24", "mid-lunch-2026-09-24", nil])
        #expect(model.rows[1].category == .meal)
    }

    @Test func afterEightPMTomorrowsBagCountsAsUpcoming() async {
        let (model, _) = await favorites(at: Fixture.sep(24, 20, 30))
        let mid = model.rows.first { $0.restaurantID == "mid" }
        #expect(mid?.status == .upcoming("Opens tomorrow at 7:00 AM"))
        #expect(mid?.nextOfferID == "mid-tmrw-2026-09-25")
    }

    @Test func swipeToRemove() async {
        let (model, harness) = await favorites()
        await model.remove(["near"])
        #expect(harness.userData.favoriteIDs.sorted() == ["far", "mid"])
        #expect(!model.rows.contains { $0.restaurantID == "near" })
    }

    @Test func alertsOnAfterPermission() async {
        let (model, harness) = await favorites()
        await model.toggleAlerts(for: "mid")
        #expect(model.rows.first { $0.restaurantID == "mid" }?.alertsOn == true)
        #expect(!model.notificationsBlocked)
        await model.toggleAlerts(for: "mid")
        #expect(model.rows.first { $0.restaurantID == "mid" }?.alertsOn == false)
        _ = harness
    }

    @Test func deniedPermissionShowsTheSettingsAlert() async {
        let (model, harness) = await favorites()
        harness.notifications.setPermission(false)
        await model.toggleAlerts(for: "mid")
        #expect(model.notificationsBlocked)
        #expect(model.rows.allSatisfy { !$0.alertsOn })
    }

    @Test func previewSendsAFavoritesBagThenResets() async {
        let (model, harness) = await favorites()
        await model.sendPreview()
        #expect(harness.notifications.previewOfferIDs.count == 1)
        #expect(
            harness.notifications.previewOfferIDs[0].hasPrefix("near")
                || harness.notifications.previewOfferIDs[0].hasPrefix("mid"))
        #expect(!model.previewSent)  // reset after the (short) delay
    }

    @Test func previewDeniedShowsTheAlert() async {
        let (model, harness) = await favorites()
        harness.notifications.setPermission(false)
        await model.sendPreview()
        #expect(model.notificationsBlocked)
        #expect(harness.notifications.previewOfferIDs.isEmpty)
    }

    @Test func notificationsFlagOffHidesBellsAndPreview() async {
        let (model, harness) = await favorites(flags: Fixture.flags(notifications: false))
        #expect(!model.showsAlerts)
        await model.toggleAlerts(for: "mid")
        await model.sendPreview()
        #expect(model.rows.allSatisfy { !$0.alertsOn })
        #expect(harness.notifications.previewOfferIDs.isEmpty)
    }
}
