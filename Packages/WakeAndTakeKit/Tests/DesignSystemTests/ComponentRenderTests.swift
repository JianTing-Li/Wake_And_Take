//
//  ComponentRenderTests.swift
//  DesignSystemTests
//
//  Renders every component in light, dark and accessibility text sizes. Set
//  TEST_RUNNER_SNAPSHOT_DIR when running xcodebuild to also write PNGs for review.
//

import Domain
import SwiftUI
import Testing
import UIKit

@testable import DesignSystem

@MainActor
@Suite("Component rendering")
struct ComponentRenderTests {
    enum Variant: String, CaseIterable {
        case light, dark, largeText

        var scheme: ColorScheme { self == .dark ? .dark : .light }
        var typeSize: DynamicTypeSize { self == .largeText ? .accessibility3 : .large }
    }

    static let components: [(String, AnyView)] = [
        ("BagCard", AnyView(BagCard(PreviewSamples.bagCard, isFavorite: true) {})),
        ("BagCardSoldOut", AnyView(BagCard(PreviewSamples.bagCardSoldOut))),
        ("BagCardTomorrow", AnyView(BagCard(PreviewSamples.bagCardTomorrow) {})),
        ("MapBagCard", AnyView(MapBagCard(PreviewSamples.mapCard, onView: {}, onClose: {}))),
        ("StatusBadge", AnyView(StatusBadge(text: "Ends in 12 min", isUrgent: true))),
        ("FavoriteButton", AnyView(FavoriteButton(isFavorite: true) {})),
        (
            "PricePin",
            AnyView(
                PricePin(
                    category: .meal, price: Money(cents: 899), state: .opensLater, isSelected: true,
                    accessibilityText: "Night Owl"))
        ),
        (
            "ImpactCard",
            AnyView(ImpactCard(impact: Impact(bagsRescued: 7, moneySaved: Money(cents: 8423), co2eAvoidedKg: 17.5)))
        ),
        ("PickupStatusPill", AnyView(PickupStatusPill(text: "Picked up", tone: .collected, rating: 4))),
        ("StarRating", AnyView(StarRating(rating: .constant(3), size: 36))),
        ("StarsDisplay", AnyView(StarsDisplay(rating: 4))),
        ("FlowTags", AnyView(FlowTags(selection: .constant([.fresh])))),
        ("SwipeToConfirm", AnyView(SwipeToConfirm(title: "Swipe to confirm pickup") {})),
        ("WeekdayPicker", AnyView(WeekdayPicker(selection: .constant([2, 3, 4, 5, 6])))),
        ("DayLabel", AnyView(DayLabel("Tomorrow", day: .tomorrow))),
        ("LocationBanner", AnyView(LocationBanner(reason: .permissionDenied) {})),
        ("LoadingView", AnyView(LoadingView("Finding bags near you…").frame(height: 120))),
        ("EmptyStateView", AnyView(EmptyStateView("No orders yet", systemImage: "bag", message: "Reserve a bag."))),
        ("CategoryTile", AnyView(CategoryTile(category: .grocery))),
        ("PriceStack", AnyView(PriceStack(price: Money(cents: 599), estimatedValue: Money(cents: 1800)))),
    ]

    @Test(arguments: Variant.allCases)
    func everyComponentRenders(variant: Variant) throws {
        for (name, view) in Self.components {
            let framed =
                view
                .padding(16)
                .frame(width: 390)
                .background(Color(.systemGroupedBackground))
                .environment(\.colorScheme, variant.scheme)
                .dynamicTypeSize(variant.typeSize)
            let renderer = ImageRenderer(content: framed)
            renderer.scale = 2
            let image = try #require(renderer.uiImage, "\(name) didn't render")
            #expect(image.size.width == 390, "\(name)")
            #expect(image.size.height > 16, "\(name)")
            if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let png = image.pngData() {
                try png.write(to: URL(filePath: dir).appending(path: "\(name)-\(variant.rawValue).png"))
            }
        }
    }

    @Test func largeTextMakesBagCardsTallerInsteadOfTruncating() throws {
        func height(_ size: DynamicTypeSize) throws -> CGFloat {
            let view = BagCard(PreviewSamples.bagCardTomorrow).frame(width: 358).dynamicTypeSize(size)
            return try #require(ImageRenderer(content: view).uiImage).size.height
        }
        #expect(try height(.accessibility3) > height(.large) * 1.4)
    }
}

@Suite("Styles & formatting")
struct StyleTests {
    @Test func everyCategoryHasItsOwnSymbol() {
        let symbols = FoodCategory.allCases.map(\.symbol)
        #expect(Set(symbols).count == FoodCategory.allCases.count)
        #expect(FoodCategory.meal.symbol == "fork.knife")
    }

    @Test func draftSymbolsArePreserved() {
        #expect(FoodCategory.bakery.symbol == "birthday.cake.fill")
        #expect(DietaryTag.glutenFree.symbol == "laurel.leading")
        #expect(TravelMode.subway.symbol == "tram.fill")
    }

    @Test func moneyFormatsAsUSD() {
        #expect(Money(cents: 599).usd.contains("5.99"))
        #expect(Money(cents: 0).usd.contains("0.00"))
    }

    @Test func locationBannerCopy() {
        #expect(LocationBanner(reason: .noFix).title == "Showing offers near Long Island City")
        #expect(LocationBanner(reason: .outOfServiceArea).title == "Wake&Take is launching in LIC")
    }
}
