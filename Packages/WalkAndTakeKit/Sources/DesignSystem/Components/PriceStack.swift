//
//  PriceStack.swift
//  WalkAndTakeKit
//

import Domain
import SwiftUI

/// Struck-through estimated value over the bold price. Never truncates.
public struct PriceStack: View {
    public enum Size { case title3, title2 }

    let price: Money
    let estimatedValue: Money
    var size: Size = .title3

    public init(price: Money, estimatedValue: Money, size: Size = .title3) {
        self.price = price
        self.estimatedValue = estimatedValue
        self.size = size
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(estimatedValue.usd)
                .font(.caption)
                .strikethrough()
                .foregroundStyle(.secondary)
            Text(price.usd)
                .font(size == .title3 ? .title3.weight(.bold) : .title2.weight(.bold))
                .foregroundStyle(Color.splashTeal)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(price.usd), was \(estimatedValue.usd)")
    }
}

#Preview("Light") {
    PriceStack(price: Money(cents: 599), estimatedValue: Money(cents: 1800)).padding()
}

#Preview("Dark · large text") {
    PriceStack(price: Money(cents: 999), estimatedValue: Money(cents: 3000), size: .title2)
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
