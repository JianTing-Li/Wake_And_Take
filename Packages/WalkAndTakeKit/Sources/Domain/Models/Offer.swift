//
//  Offer.swift
//  WalkAndTakeKit
//

import Foundation

/// One day's surprise bag from a restaurant. Contents aren't itemized;
/// `summary` says what the bag may include.
public struct Offer: Identifiable, Hashable, Codable, Sendable {
    /// `"<templateID>-<yyyy-MM-dd>"`, using the New York day.
    public let id: String
    public let templateID: String
    public let restaurantID: String
    public var name: String
    public var category: FoodCategory
    public var summary: String
    public var dietary: Set<DietaryTag>
    public var price: Money
    public var estimatedValue: Money
    public var quantityTotal: Int
    /// Bags held by anyone, including simulated other customers.
    public var quantityReserved: Int
    public var pickupWindow: PickupWindow

    public init(
        id: String,
        templateID: String,
        restaurantID: String,
        name: String,
        category: FoodCategory,
        summary: String,
        dietary: Set<DietaryTag>,
        price: Money,
        estimatedValue: Money,
        quantityTotal: Int,
        quantityReserved: Int,
        pickupWindow: PickupWindow
    ) {
        self.id = id
        self.templateID = templateID
        self.restaurantID = restaurantID
        self.name = name
        self.category = category
        self.summary = summary
        self.dietary = dietary
        self.price = price
        self.estimatedValue = estimatedValue
        self.quantityTotal = quantityTotal
        self.quantityReserved = quantityReserved
        self.pickupWindow = pickupWindow
    }

    /// Builds the stable ID for a template's offer on a given day.
    public static func makeID(templateID: String, day: DayKey) -> String {
        "\(templateID)-\(day.rawValue)"
    }

    public var quantityLeft: Int { max(0, quantityTotal - quantityReserved) }

    public var isSoldOut: Bool { quantityLeft == 0 }

    /// Discount off the estimated value, rounded to a whole percent.
    public var savingsPercent: Int {
        guard estimatedValue.cents > 0 else { return 0 }
        let saved = Double(estimatedValue.cents - price.cents) / Double(estimatedValue.cents)
        return Int((saved * 100).rounded())
    }
}
