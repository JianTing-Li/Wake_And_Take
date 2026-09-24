//
//  RateOrderPlaceholderView.swift
//  WakeAndTakeKit
//
//  Temporary stand-in until Phase 4f ports rating.
//

import DesignSystem
import SwiftUI

struct RateOrderPlaceholderView: View {
    let request: RateRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EmptyStateView(
                "Ratings coming in 4f",
                systemImage: "star.bubble",
                message: "You tapped \(request.stars) star\(request.stars == 1 ? "" : "s"). Rating is being rebuilt."
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
