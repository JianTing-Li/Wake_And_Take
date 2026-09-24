//
//  CategoryChips.swift
//  WakeAndTakeKit
//

import DesignSystem
import Domain
import SwiftUI

/// "All" plus one chip per category; tapping filters Discover.
struct CategoryChips: View {
    @Binding var selection: FoodCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", symbol: "square.grid.2x2.fill", selected: selection == nil) { selection = nil }
                ForEach(FoodCategory.allCases) { category in
                    chip(category.label, symbol: category.symbol, selected: selection == category) {
                        selection = category
                    }
                }
            }
        }
    }

    private func chip(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.splashTeal : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
