//
//  SeedTests.swift
//  MockDataTests
//

import Domain
import Foundation
import Platform
import Testing

@testable import MockData

@Suite("Seed loading & validation")
struct SeedTests {
    func template(
        id: String = "tpl_a",
        restaurantID: String = "rst_a",
        total: Int = 5,
        simulated: Int = 0,
        start: String = "07:30",
        end: String = "10:00"
    ) -> OfferTemplate {
        OfferTemplate(
            id: id, restaurantID: restaurantID, name: "Bag", category: .breakfast, summary: "",
            dietary: [], price: Money(cents: 499), estimatedValue: Money(cents: 1500),
            quantityTotal: total, simulatedReservedCount: simulated, pickupStart: start, pickupEnd: end
        )
    }

    var restaurant: Restaurant { TestEnv.seed.restaurants[0] }

    @Test func bundledSeedIsValid() {
        let seed = TestEnv.seed
        #expect(seed.restaurants.count == 21)
        #expect(seed.templates.count == 32)
        #expect(seed.version.rawValue == "r2-t2")
        #expect(SeedLoader.validate(restaurants: seed.restaurants, templates: seed.templates).isEmpty)
        let early = seed.restaurants.first { $0.id == "rst_early_bird_bakehouse" }
        #expect(early?.kind == .bakery)
        #expect(early?.address.intersection == "Vernon Blvd & 48th Ave")
    }

    @Test func duplicateIDs() {
        let issues = SeedLoader.validate(
            restaurants: [restaurant, restaurant],
            templates: [template(restaurantID: restaurant.id), template(restaurantID: restaurant.id)]
        )
        #expect(issues.contains(.duplicateRestaurantID(restaurant.id)))
        #expect(issues.contains(.duplicateTemplateID("tpl_a")))
    }

    @Test func unknownRestaurant() {
        let issues = SeedLoader.validate(restaurants: [restaurant], templates: [template(restaurantID: "rst_nope")])
        #expect(issues == [.unknownRestaurant(templateID: "tpl_a", restaurantID: "rst_nope")])
    }

    @Test(arguments: [-1, 6])
    func simulatedCountOutOfRange(simulated: Int) {
        let issues = SeedLoader.validate(
            restaurants: [restaurant], templates: [template(restaurantID: restaurant.id, simulated: simulated)])
        #expect(issues == [.invalidSimulatedCount(templateID: "tpl_a")])
    }

    @Test func simulatedCountAtBoundsIsFine() {
        let templates = [
            template(id: "a", restaurantID: restaurant.id, simulated: 0),
            template(id: "b", restaurantID: restaurant.id, simulated: 5),
        ]
        #expect(SeedLoader.validate(restaurants: [restaurant], templates: templates).isEmpty)
    }

    @Test func windowRules() {
        let r = restaurant.id
        let cases: [(OfferTemplate, SeedIssue)] = [
            (template(restaurantID: r, start: "10:00", end: "10:00"), .windowNotForward(templateID: "tpl_a")),
            (template(restaurantID: r, start: "22:00", end: "01:00"), .windowNotForward(templateID: "tpl_a")),
            (template(restaurantID: r, start: "07:00", end: "10:31"), .windowTooLong(templateID: "tpl_a")),
            (
                template(restaurantID: r, start: "23:00", end: "24:00"),
                .malformedTime(templateID: "tpl_a", value: "24:00")
            ),
            (
                template(restaurantID: r, start: "7:30", end: "10:00"),
                .malformedTime(templateID: "tpl_a", value: "7:30")
            ),
        ]
        for (t, expected) in cases {
            #expect(SeedLoader.validate(restaurants: [restaurant], templates: [t]) == [expected])
        }
        // Exactly 3.5 h and ending at 23:59 are allowed.
        let ok = [
            template(id: "a", restaurantID: r, start: "07:00", end: "10:30"),
            template(id: "b", restaurantID: r, start: "21:00", end: "23:59"),
        ]
        #expect(SeedLoader.validate(restaurants: [restaurant], templates: ok).isEmpty)
    }

    @Test func wrongTimeZoneIsRejected() throws {
        let restaurants = Data(#"{"schemaVersion":1,"restaurants":[]}"#.utf8)
        let templates = Data(#"{"schemaVersion":1,"timeZone":"UTC","templates":[]}"#.utf8)
        #expect(throws: SeedError.self) {
            try SeedLoader.decode(restaurantsJSON: restaurants, templatesJSON: templates)
        }
    }

    @Test func generatorBuildsNewYorkWindows() throws {
        let template = try #require(TestEnv.seed.templates.first { $0.id == "tpl_early_bird_breakfast" })
        let offer = try #require(DailyOfferGenerator.offer(from: template, on: DayKey(rawValue: "2026-09-25")))
        #expect(offer.id == "tpl_early_bird_breakfast-2026-09-25")
        #expect(offer.pickupWindow.start == TestEnv.sep(25, 7, 30))
        #expect(offer.pickupWindow.end == TestEnv.sep(25, 10, 0))
        #expect(offer.quantityReserved == template.simulatedReservedCount)
        #expect(offer.price == Money(cents: 599))
    }
}
