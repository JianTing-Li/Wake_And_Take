//
//  CommuteProfile.swift
//  Wake_And_Take
//

import Foundation

enum DietaryTag: String, CaseIterable, Identifiable, Codable {
    case vegetarian, vegan, glutenFree, dairyFree

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .dairyFree: "Dairy-free"
        }
    }

    var symbol: String {
        switch self {
        case .vegetarian: "leaf"
        case .vegan: "leaf.circle"
        case .glutenFree: "laurel.leading"
        case .dairyFree: "drop.triangle"
        }
    }
}

enum TravelMode: String, CaseIterable, Identifiable, Codable {
    case walk, subway, bike, drive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walk: "Walk"
        case .subway: "Subway"
        case .bike: "Bike"
        case .drive: "Drive"
        }
    }

    var symbol: String {
        switch self {
        case .walk: "figure.walk"
        case .subway: "tram.fill"
        case .bike: "bicycle"
        case .drive: "car.fill"
        }
    }
}

/// The customer's morning routine and food preferences.
struct CommuteProfile: Codable, Equatable {
    var name = ""
    var homeArea = "Long Island City"

    /// Minutes after midnight.
    var leaveMinutes = 7 * 60 + 30
    var arriveMinutes = 8 * 60 + 30
    /// Calendar weekdays (1 = Sunday … 7 = Saturday).
    var commuteDays: Set<Int> = [2, 3, 4, 5, 6]
    var travelMode: TravelMode = .subway
    var maxDistanceMiles = 1.0

    var dietary: Set<DietaryTag> = []

    static let distanceOptions = [0.25, 0.5, 1.0, 1.5, 2.0]

    var isCommuteValid: Bool { arriveMinutes > leaveMinutes }

    /// Today's commute window, or nil if today isn't a commute day.
    func commuteWindow(on day: Date, calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard isCommuteValid, commuteDays.contains(calendar.component(.weekday, from: day)) else { return nil }
        let midnight = calendar.startOfDay(for: day)
        return midnight.addingTimeInterval(Double(leaveMinutes) * 60)...midnight.addingTimeInterval(Double(arriveMinutes) * 60)
    }

    /// True when the bag's pickup window overlaps today's commute.
    func fitsCommute(_ bag: SurplusBag, on day: Date) -> Bool {
        guard let window = commuteWindow(on: day) else { return false }
        return bag.pickupStart < window.upperBound && bag.pickupEnd > window.lowerBound
    }

    /// True when the bag is close enough and suits every dietary preference.
    func matches(_ bag: SurplusBag) -> Bool {
        bag.distanceMiles <= maxDistanceMiles && dietary.isSubset(of: bag.dietary)
    }
}
