//
//  OfferEntity.swift
//  WalkAndTakeKit
//

import Domain
import Foundation
import SwiftData

@Model
final class OfferEntity {
    #Unique<OfferEntity>([\.id])
    #Index<OfferEntity>([\.dayKey])

    var id: String
    var templateID: String
    var restaurantID: String
    /// New York day, "yyyy-MM-dd".
    var dayKey: String
    var name: String
    var categoryRaw: String
    var summary: String
    var dietaryRaw: [String]
    var priceCents: Int
    var estimatedValueCents: Int
    var quantityTotal: Int
    var quantityReserved: Int
    var pickupStart: Date
    var pickupEnd: Date

    init(_ offer: Offer, dayKey: DayKey) {
        id = offer.id
        templateID = offer.templateID
        restaurantID = offer.restaurantID
        self.dayKey = dayKey.rawValue
        name = offer.name
        categoryRaw = offer.category.rawValue
        summary = offer.summary
        dietaryRaw = offer.dietary.map(\.rawValue).sorted()
        priceCents = offer.price.cents
        estimatedValueCents = offer.estimatedValue.cents
        quantityTotal = offer.quantityTotal
        quantityReserved = offer.quantityReserved
        pickupStart = offer.pickupWindow.start
        pickupEnd = offer.pickupWindow.end
    }

    var domain: Offer {
        Offer(
            id: id,
            templateID: templateID,
            restaurantID: restaurantID,
            name: name,
            category: FoodCategory(rawValue: categoryRaw) ?? .meal,
            summary: summary,
            dietary: Set(dietaryRaw.compactMap(DietaryTag.init(rawValue:))),
            price: Money(cents: priceCents),
            estimatedValue: Money(cents: estimatedValueCents),
            quantityTotal: quantityTotal,
            quantityReserved: quantityReserved,
            pickupWindow: PickupWindow(start: pickupStart, end: pickupEnd)
        )
    }

    var quantityLeft: Int { max(0, quantityTotal - quantityReserved) }
}
