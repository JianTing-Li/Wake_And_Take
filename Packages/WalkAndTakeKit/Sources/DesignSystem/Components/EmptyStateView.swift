//
//  EmptyStateView.swift
//  WalkAndTakeKit
//

import SwiftUI

/// The draft's empty/error states: symbol, title, message, and an optional prominent action.
public struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        _ title: String,
        systemImage: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.splashTeal)
            }
        }
    }
}

#Preview("Light") {
    EmptyStateView(
        "No orders yet",
        systemImage: "bag",
        message: "Reserve a surprise bag and it will show up here with your pickup code.",
        actionTitle: "Find food nearby"
    ) {}
}

#Preview("Dark") {
    EmptyStateView(
        "No bags right now",
        systemImage: "bag",
        message: "Check back soon. Stores add bags throughout the day."
    )
    .preferredColorScheme(.dark)
}

#Preview("Large text") {
    EmptyStateView(
        "No favorites yet",
        systemImage: "heart",
        message: "Tap the heart on any store to save it here.",
        actionTitle: "Browse stores"
    ) {}
    .dynamicTypeSize(.accessibility2)
}
