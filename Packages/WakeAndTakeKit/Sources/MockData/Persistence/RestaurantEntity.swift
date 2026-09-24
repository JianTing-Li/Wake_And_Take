//
//  RestaurantEntity.swift
//  WakeAndTakeKit
//

import Domain
import Foundation
import SwiftData

@Model
final class RestaurantEntity {
    #Unique<RestaurantEntity>([\.id])

    var id: String
    var name: String
    var kindRaw: String
    var street: String
    var crossStreet: String
    var neighborhood: String
    var borough: String
    var zip: String
    var latitude: Double
    var longitude: Double
    var pickupInstructions: String
    var rating: Double
    var reviewCount: Int

    init(_ restaurant: Restaurant) {
        id = restaurant.id
        name = restaurant.name
        kindRaw = restaurant.kind.rawValue
        street = restaurant.address.street
        crossStreet = restaurant.address.crossStreet
        neighborhood = restaurant.address.neighborhood
        borough = restaurant.address.borough
        zip = restaurant.address.zip
        latitude = restaurant.coordinate.latitude
        longitude = restaurant.coordinate.longitude
        pickupInstructions = restaurant.pickupInstructions
        rating = restaurant.rating
        reviewCount = restaurant.reviewCount
    }

    /// Overwrites everything from seed data (used when the seed version changes).
    func update(from restaurant: Restaurant) {
        name = restaurant.name
        kindRaw = restaurant.kind.rawValue
        street = restaurant.address.street
        crossStreet = restaurant.address.crossStreet
        neighborhood = restaurant.address.neighborhood
        borough = restaurant.address.borough
        zip = restaurant.address.zip
        latitude = restaurant.coordinate.latitude
        longitude = restaurant.coordinate.longitude
        pickupInstructions = restaurant.pickupInstructions
        rating = restaurant.rating
        reviewCount = restaurant.reviewCount
    }

    var domain: Restaurant {
        Restaurant(
            id: id,
            name: name,
            kind: Restaurant.Kind(rawValue: kindRaw) ?? .restaurant,
            address: Restaurant.Address(
                street: street,
                crossStreet: crossStreet,
                neighborhood: neighborhood,
                borough: borough,
                zip: zip
            ),
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            pickupInstructions: pickupInstructions,
            rating: rating,
            reviewCount: reviewCount
        )
    }
}
