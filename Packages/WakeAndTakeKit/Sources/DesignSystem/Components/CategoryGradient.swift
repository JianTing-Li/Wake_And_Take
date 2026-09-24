//
//  CategoryGradient.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// The category-tinted gradient with its symbol, used as a bag's "photo".
public struct CategoryGradient: View {
    let category: FoodCategory
    let symbolSize: CGFloat

    public init(category: FoodCategory, symbolSize: CGFloat) {
        self.category = category
        self.symbolSize = symbolSize
    }

    public var body: some View {
        LinearGradient(
            colors: [category.tint, category.tint.opacity(0.7)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: category.symbol)
                .font(.system(size: symbolSize))
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityHidden(true)
        }
    }
}

#Preview("Light") {
    CategoryGradient(category: .meal, symbolSize: 42).frame(height: 100).padding()
}

#Preview("Dark") {
    CategoryGradient(category: .bakery, symbolSize: 64).frame(height: 180).preferredColorScheme(.dark)
}
