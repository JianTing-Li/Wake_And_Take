//
//  OfferTemplate.swift
//  WakeAndTakeKit
//

import Domain
import Foundation

/// A daily offer definition from `offer_templates.json`. Times are New York `HH:mm`.
public struct OfferTemplate: Hashable, Sendable, Decodable {
    public var id: String
    public var restaurantID: String
    public var name: String
    public var category: FoodCategory
    public var summary: String
    public var dietary: Set<DietaryTag>
    public var price: Money
    public var estimatedValue: Money
    public var quantityTotal: Int
    /// Stands in for other customers; adds to `quantityReserved`, creates no reservations.
    public var simulatedReservedCount: Int
    public var pickupStart: String
    public var pickupEnd: String

    public init(
        id: String,
        restaurantID: String,
        name: String,
        category: FoodCategory,
        summary: String,
        dietary: Set<DietaryTag>,
        price: Money,
        estimatedValue: Money,
        quantityTotal: Int,
        simulatedReservedCount: Int,
        pickupStart: String,
        pickupEnd: String
    ) {
        self.id = id
        self.restaurantID = restaurantID
        self.name = name
        self.category = category
        self.summary = summary
        self.dietary = dietary
        self.price = price
        self.estimatedValue = estimatedValue
        self.quantityTotal = quantityTotal
        self.simulatedReservedCount = simulatedReservedCount
        self.pickupStart = pickupStart
        self.pickupEnd = pickupEnd
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, summary, dietary, quantityTotal, simulatedReservedCount, pickupStart, pickupEnd
        case restaurantID = "restaurantId"
        case priceCents, estimatedValueCents
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        restaurantID = try c.decode(String.self, forKey: .restaurantID)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(FoodCategory.self, forKey: .category)
        summary = try c.decode(String.self, forKey: .summary)
        dietary = try c.decode(Set<DietaryTag>.self, forKey: .dietary)
        price = Money(cents: try c.decode(Int.self, forKey: .priceCents))
        estimatedValue = Money(cents: try c.decode(Int.self, forKey: .estimatedValueCents))
        quantityTotal = try c.decode(Int.self, forKey: .quantityTotal)
        simulatedReservedCount = try c.decode(Int.self, forKey: .simulatedReservedCount)
        pickupStart = try c.decode(String.self, forKey: .pickupStart)
        pickupEnd = try c.decode(String.self, forKey: .pickupEnd)
    }

    /// Minutes after midnight for an `HH:mm` string, or nil if malformed.
    static func minutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
            let hour = Int(parts[0]), let minute = Int(parts[1]),
            (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }

    var startMinutes: Int? { Self.minutes(pickupStart) }
    var endMinutes: Int? { Self.minutes(pickupEnd) }
}
