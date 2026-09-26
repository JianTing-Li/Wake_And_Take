//
//  NotificationAndCodeTests.swift
//  PlatformTests
//

import CoreGraphics
import Domain
import Foundation
import Testing

@testable import Platform

@Suite("Notification plan")
struct NotificationPlanTests {
    let key = DayKey(rawValue: "2026-09-24")

    func alert(startHour: Int) -> OfferAlert {
        OfferAlert(
            offerID: "tpl_early_bird_breakfast-2026-09-24",
            restaurantName: "Early Bird Bakehouse",
            bagName: "Breakfast Surprise Bag",
            price: Money(cents: 599),
            estimatedValue: Money(cents: 1800),
            pickupWindow: PickupWindow(
                start: NYCalendar.date(on: key, hour: startHour, minute: 30)!,
                end: NYCalendar.date(on: key, hour: startHour + 2, minute: 30)!
            )
        )
    }

    @Test func identifiersUseStableOfferIDs() {
        #expect(NotificationPlan.identifier(forOfferID: "tpl_x-2026-09-24") == "drop-tpl_x-2026-09-24")
    }

    @Test func copyMatchesTheDraftWithMoneyFormatting() {
        let a = alert(startHour: 7)
        #expect(NotificationPlan.title(for: a) == "Early Bird Bakehouse has bags ready")
        #expect(NotificationPlan.body(for: a) == "Breakfast Surprise Bag for $5.99 (was $18.00). Pick up 7:30–9:30 AM.")
    }

    @Test func alertPlanUsesFavoritesWithAlertsOnly() {
        func offer(_ id: String, restaurant: String, startHour: Int, reserved: Int = 0) -> Offer {
            Offer(
                id: id, templateID: id, restaurantID: restaurant, name: "Bag", category: .bakery, summary: "",
                dietary: [], price: Money(cents: 500), estimatedValue: Money(cents: 1500), quantityTotal: 3,
                quantityReserved: reserved,
                pickupWindow: PickupWindow(
                    start: NYCalendar.date(on: key, hour: startHour, minute: 0)!,
                    end: NYCalendar.date(on: key, hour: startHour + 1, minute: 0)!))
        }
        func restaurant(_ id: String) -> Restaurant {
            Restaurant(
                id: id, name: "Name \(id)", kind: .cafe,
                address: .init(street: "", crossStreet: "", neighborhood: "", borough: "", zip: ""),
                coordinate: Coordinate(latitude: 0, longitude: 0), pickupInstructions: "", rating: 4,
                reviewCount: 1)
        }
        let now = NYCalendar.date(on: key, hour: 8, minute: 0)!
        let offers = [
            offer("a-later", restaurant: "a", startHour: 12),
            offer("a-open", restaurant: "a", startHour: 7),
            offer("a-soldout", restaurant: "a", startHour: 13, reserved: 3),
            offer("b-later", restaurant: "b", startHour: 12),
            offer("c-later", restaurant: "c", startHour: 12),
        ]
        let favorites = [
            FavoriteRestaurant(restaurantID: "a", alertsEnabled: true),
            FavoriteRestaurant(restaurantID: "b", alertsEnabled: false),
        ]
        let plan = NotificationPlan.alerts(
            for: favorites, offers: offers, restaurants: ["a", "b", "c"].map(restaurant), now: now)
        #expect(plan.map(\.offerID) == ["a-later"])
        #expect(plan.first?.restaurantName == "Name a")
    }

    @Test func onlyWindowsThatHaventOpenedAreScheduled() {
        let now = NYCalendar.date(on: key, hour: 8, minute: 0)!
        let alerts = [alert(startHour: 7), alert(startHour: 9)]
        #expect(NotificationPlan.upcoming(alerts, now: now).map(\.pickupWindow.start) == [alerts[1].pickupWindow.start])
    }
}

@Suite("Codes")
struct CodeTests {
    @Test func pickupCodesUseTheUnambiguousAlphabet() {
        let generator = RandomPickupCodeGenerator()
        let allowed = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<500 {
            let code = generator.makeCode()
            #expect(code.count == 4)
            #expect(code.allSatisfy(allowed.contains))
        }
        #expect(!allowed.contains("O") && !allowed.contains("0") && !allowed.contains("I") && !allowed.contains("1"))
    }

    @Test func qrCodeRenders() throws {
        let image = try #require(QRCodeGenerator.image(for: "AB23", scale: 10))
        #expect(image.width == image.height)
        #expect(image.width >= 210)  // 21 modules minimum × 10
    }
}
