//
//  FoodCategory.swift
//  WalkAndTakeKit
//
//  Symbols and colors live in DesignSystem (FoodCategory+Style).
//

import Foundation

public enum FoodCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case breakfast, bakery, coffee, meal, grocery

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .breakfast: "Breakfast"
        case .bakery: "Bakery"
        case .coffee: "Coffee"
        case .meal: "Meal"
        case .grocery: "Grocery"
        }
    }
}
