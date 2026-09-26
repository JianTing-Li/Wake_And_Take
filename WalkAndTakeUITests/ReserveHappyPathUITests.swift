//
//  ReserveHappyPathUITests.swift
//  WalkAndTakeUITests
//
//  Discover → offer → reserve → confirmation → Orders shows the reservation's code.
//  Runs against a fresh in-memory store, a clock frozen at 8:00 AM New York
//  (breakfast windows open), a fixed LIC location (no permission prompt), and no splash.
//

import XCTest

@MainActor
final class ReserveHappyPathUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testReserveThenOrdersShowsTheCode() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestInMemoryStore",
            "-UITestNow", "2026-09-24T08:00:00-04:00",
            "-UITestFixedLocation",
            "-UITestSkipSplash",
        ]
        app.launch()

        // Discover: open the first bag (sorted "Ending soon", so an open breakfast bag).
        let card = app.buttons.matching(identifier: "discover.bagCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Discover never showed a bag")
        card.tap()

        // Offer detail: reserve.
        let reserve = app.buttons["offerDetail.reserve"]
        XCTAssertTrue(reserve.waitForExistence(timeout: 5))
        XCTAssertTrue(reserve.label.hasPrefix("Reserve"), "Unexpected button: \(reserve.label)")
        reserve.tap()

        // Confirmation: read the code, then view the order.
        let confirmationCode = app.staticTexts["confirmation.code"]
        XCTAssertTrue(confirmationCode.waitForExistence(timeout: 5))
        let code = Self.code(from: confirmationCode.label)
        XCTAssertEqual(code.count, 4, "Code was \(confirmationCode.label)")
        app.buttons["confirmation.viewOrder"].tap()

        // Orders: the pickup screen for this reservation shows the same code.
        let pickupCode = app.staticTexts["pickup.code"]
        XCTAssertTrue(pickupCode.waitForExistence(timeout: 5))
        XCTAssertEqual(Self.code(from: pickupCode.label), code)
        XCTAssertTrue(app.tabBars.buttons["Orders"].isSelected)

        // And the Orders list has the order.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: 5))
        let orderRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "×")).firstMatch
        XCTAssertTrue(orderRow.waitForExistence(timeout: 5), "Orders list has no order row")
    }

    /// "Pickup code K S 8 9" → "KS89"
    private static func code(from label: String) -> String {
        label.replacingOccurrences(of: "Pickup code", with: "").replacingOccurrences(of: " ", with: "")
    }
}
