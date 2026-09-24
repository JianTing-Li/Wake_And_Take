//
//  OfferSnapshot.swift
//  WakeAndTakeKit
//

import Foundation

/// What the customer saw when they reserved. Order screens read this,
/// never the live offer, so later changes (or pruning) can't alter an order.
public struct OfferSnapshot: Hashable, Codable, Sendable {
    public let offerID: String
    public let restaurantID: String
    public let restaurantName: String
    public let address: Restaurant.Address
    public let coordinate: Coordinate
    public let pickupInstructions: String
    public let bagName: String
    public let category: FoodCategory
    public let summary: String
    public let unitPrice: Money
    public let estimatedValue: Money
    public let pickupWindow: PickupWindow

    public init(
        offerID: String,
        restaurantID: String,
        restaurantName: String,
        address: Restaurant.Address,
        coordinate: Coordinate,
        pickupInstructions: String,
        bagName: String,
        category: FoodCategory,
        summary: String,
        unitPrice: Money,
        estimatedValue: Money,
        pickupWindow: PickupWindow
    ) {
        self.offerID = offerID
        self.restaurantID = restaurantID
        self.restaurantName = restaurantName
        self.address = address
        self.coordinate = coordinate
        self.pickupInstructions = pickupInstructions
        self.bagName = bagName
        self.category = category
        self.summary = summary
        self.unitPrice = unitPrice
        self.estimatedValue = estimatedValue
        self.pickupWindow = pickupWindow
    }

    public init(offer: Offer, restaurant: Restaurant) {
        self.init(
            offerID: offer.id,
            restaurantID: restaurant.id,
            restaurantName: restaurant.name,
            address: restaurant.address,
            coordinate: restaurant.coordinate,
            pickupInstructions: restaurant.pickupInstructions,
            bagName: offer.name,
            category: offer.category,
            summary: offer.summary,
            unitPrice: offer.price,
            estimatedValue: offer.estimatedValue,
            pickupWindow: offer.pickupWindow
        )
    }
}
