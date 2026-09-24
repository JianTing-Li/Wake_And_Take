//
//  FavoriteButton.swift
//  WakeAndTakeKit
//

import SwiftUI

/// Heart toggle drawn over a bag image.
public struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    public init(isFavorite: Bool, action: @escaping () -> Void) {
        self.isFavorite = isFavorite
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.body.weight(.semibold))
                .foregroundStyle(isFavorite ? .red : .white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.35), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

#Preview("Light") {
    HStack {
        FavoriteButton(isFavorite: false) {}
        FavoriteButton(isFavorite: true) {}
    }
    .padding()
    .background(Color.orange)
}

#Preview("Dark · large text") {
    HStack {
        FavoriteButton(isFavorite: false) {}
        FavoriteButton(isFavorite: true) {}
    }
    .padding()
    .background(Color.brown)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
