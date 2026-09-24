//
//  FoodCategory+Style.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

extension FoodCategory {
    public var symbol: String {
        switch self {
        case .breakfast: "takeoutbag.and.cup.and.straw.fill"
        case .bakery: "birthday.cake.fill"
        case .coffee: "cup.and.saucer.fill"
        case .meal: "fork.knife"
        case .grocery: "basket.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .breakfast: Color(red: 0.93, green: 0.55, blue: 0.20)
        case .bakery: Color(red: 0.80, green: 0.52, blue: 0.25)
        case .coffee: Color(red: 0.45, green: 0.30, blue: 0.22)
        case .meal: Color(red: 0.72, green: 0.33, blue: 0.27)
        case .grocery: Color(red: 0.30, green: 0.60, blue: 0.35)
        }
    }
}
