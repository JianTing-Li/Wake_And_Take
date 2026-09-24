//
//  SeedLoader.swift
//  WakeAndTakeKit
//

import Domain
import Foundation

/// A problem found while validating seed files.
public enum SeedIssue: Hashable, Sendable, CustomStringConvertible {
    case duplicateRestaurantID(String)
    case duplicateTemplateID(String)
    case unknownRestaurant(templateID: String, restaurantID: String)
    case invalidSimulatedCount(templateID: String)
    case invalidQuantity(templateID: String)
    case malformedTime(templateID: String, value: String)
    case windowNotForward(templateID: String)
    case windowTooLong(templateID: String)
    case wrongTimeZone(String)

    public var description: String {
        switch self {
        case .duplicateRestaurantID(let id): "Duplicate restaurant id \(id)"
        case .duplicateTemplateID(let id): "Duplicate template id \(id)"
        case .unknownRestaurant(let t, let r): "Template \(t) references unknown restaurant \(r)"
        case .invalidSimulatedCount(let t): "Template \(t): simulatedReservedCount must be 0…quantityTotal"
        case .invalidQuantity(let t): "Template \(t): quantityTotal must be positive"
        case .malformedTime(let t, let v): "Template \(t): \"\(v)\" isn't HH:mm"
        case .windowNotForward(let t): "Template \(t): pickup must start before it ends on the same day"
        case .windowTooLong(let t): "Template \(t): pickup window is longer than 3.5 h"
        case .wrongTimeZone(let tz): "Templates use time zone \(tz); expected America/New_York"
        }
    }
}

public enum SeedError: Error, Sendable {
    case missingResource(String)
    case invalid([SeedIssue])
}

public enum SeedLoader {
    /// Loads and validates the bundled JSON. Invalid seed data stops a DEBUG build immediately.
    public static func loadBundled() throws -> Seed {
        func data(_ name: String) throws -> Data {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
                throw SeedError.missingResource(name)
            }
            return try Data(contentsOf: url)
        }
        do {
            return try decode(restaurantsJSON: data("lic_restaurants"), templatesJSON: data("offer_templates"))
        } catch {
            #if DEBUG
                assertionFailure("Seed data failed to load: \(error)")
            #endif
            throw error
        }
    }

    public static func decode(restaurantsJSON: Data, templatesJSON: Data) throws -> Seed {
        let decoder = JSONDecoder()
        let restaurantFile = try decoder.decode(RestaurantFile.self, from: restaurantsJSON)
        let templateFile = try decoder.decode(TemplateFile.self, from: templatesJSON)
        let restaurants = restaurantFile.restaurants.map(\.restaurant)

        var issues = validate(restaurants: restaurants, templates: templateFile.templates)
        if templateFile.timeZone != newYorkTimeZoneID {
            issues.append(.wrongTimeZone(templateFile.timeZone))
        }
        guard issues.isEmpty else { throw SeedError.invalid(issues) }

        return Seed(
            version: SeedVersion(restaurants: restaurantFile.schemaVersion, templates: templateFile.schemaVersion),
            restaurants: restaurants,
            templates: templateFile.templates
        )
    }

    /// Every rule from the spec: unique IDs, known restaurants, sane counts, and short
    /// same-day windows (start < end, ≤ 23:59, ≤ 3.5 h).
    public static func validate(restaurants: [Restaurant], templates: [OfferTemplate]) -> [SeedIssue] {
        var issues: [SeedIssue] = []
        issues += duplicates(restaurants.map(\.id)).map(SeedIssue.duplicateRestaurantID)
        issues += duplicates(templates.map(\.id)).map(SeedIssue.duplicateTemplateID)

        let restaurantIDs = Set(restaurants.map(\.id))
        let maxMinutes = Int(PickupWindow.maxDuration / 60)
        for t in templates {
            if !restaurantIDs.contains(t.restaurantID) {
                issues.append(.unknownRestaurant(templateID: t.id, restaurantID: t.restaurantID))
            }
            if t.quantityTotal <= 0 { issues.append(.invalidQuantity(templateID: t.id)) }
            if !(0...max(t.quantityTotal, 0)).contains(t.simulatedReservedCount) {
                issues.append(.invalidSimulatedCount(templateID: t.id))
            }
            guard let start = t.startMinutes else {
                issues.append(.malformedTime(templateID: t.id, value: t.pickupStart))
                continue
            }
            guard let end = t.endMinutes else {
                issues.append(.malformedTime(templateID: t.id, value: t.pickupEnd))
                continue
            }
            // HH:mm caps the end at 23:59, so start < end also means "never crosses midnight".
            if start >= end { issues.append(.windowNotForward(templateID: t.id)) }
            if end - start > maxMinutes { issues.append(.windowTooLong(templateID: t.id)) }
        }
        return issues
    }

    private static let newYorkTimeZoneID = "America/New_York"

    private static func duplicates(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var dupes: [String] = []
        for id in ids where !seen.insert(id).inserted && !dupes.contains(id) {
            dupes.append(id)
        }
        return dupes
    }
}

// MARK: - File shapes

private struct TemplateFile: Decodable {
    var schemaVersion: Int
    var timeZone: String
    var templates: [OfferTemplate]
}

private struct RestaurantFile: Decodable {
    var schemaVersion: Int
    var restaurants: [SeedRestaurant]
}

private struct SeedRestaurant: Decodable {
    struct Address: Decodable {
        var street, crossStreet, neighborhood, borough, zip: String
    }

    var id: String
    var name: String
    var type: Restaurant.Kind
    var address: Address
    var coordinate: Coordinate
    var pickupInstructions: String
    var rating: Double
    var reviewCount: Int

    var restaurant: Restaurant {
        Restaurant(
            id: id,
            name: name,
            kind: type,
            address: Restaurant.Address(
                street: address.street,
                crossStreet: address.crossStreet,
                neighborhood: address.neighborhood,
                borough: address.borough,
                zip: address.zip
            ),
            coordinate: coordinate,
            pickupInstructions: pickupInstructions,
            rating: rating,
            reviewCount: reviewCount
        )
    }
}
