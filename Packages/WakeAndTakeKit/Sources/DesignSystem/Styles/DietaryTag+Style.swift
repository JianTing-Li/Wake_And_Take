//
//  DietaryTag+Style.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

extension DietaryTag {
    public var symbol: String {
        switch self {
        case .vegetarian: "leaf"
        case .vegan: "leaf.circle"
        case .glutenFree: "laurel.leading"
        case .dairyFree: "drop.triangle"
        }
    }
}
