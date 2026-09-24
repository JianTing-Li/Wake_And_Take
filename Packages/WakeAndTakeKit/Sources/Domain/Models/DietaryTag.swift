//
//  DietaryTag.swift
//  WakeAndTakeKit
//
//  Symbols live in DesignSystem (DietaryTag+Style).
//

import Foundation

/// A diet every item in a bag suits.
public enum DietaryTag: String, CaseIterable, Identifiable, Codable, Sendable {
    case vegetarian, vegan, glutenFree, dairyFree

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .dairyFree: "Dairy-free"
        }
    }
}
