//
//  CategoryTile.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// A rounded square with the category symbol, used in rows.
public struct CategoryTile: View {
    let category: FoodCategory?
    var size: CGFloat = 44

    public init(category: FoodCategory?, size: CGFloat = 44) {
        self.category = category
        self.size = size
    }

    public var body: some View {
        Image(systemName: category?.symbol ?? "storefront.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                category?.tint ?? .gray, in: RoundedRectangle(cornerRadius: size >= 48 ? Radius.largeTile : Radius.tile)
            )
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    HStack { ForEach(FoodCategory.allCases) { CategoryTile(category: $0) } }.padding()
}

#Preview("Dark") {
    HStack {
        ForEach(FoodCategory.allCases) { CategoryTile(category: $0, size: 48) }
        CategoryTile(category: nil)
    }
    .padding()
    .preferredColorScheme(.dark)
}
