//
//  LoadingView.swift
//  WakeAndTakeKit
//

import SwiftUI

/// Centered spinner for a screen's `loading` state.
public struct LoadingView: View {
    let message: String?

    public init(_ message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.splashTeal)
            if let message {
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

#Preview("Light") {
    LoadingView("Finding bags near you…")
}

#Preview("Dark · large text") {
    LoadingView("Finding bags near you…")
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
