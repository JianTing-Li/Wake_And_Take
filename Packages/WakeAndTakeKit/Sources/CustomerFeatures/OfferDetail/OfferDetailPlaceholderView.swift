//
//  OfferDetailPlaceholderView.swift
//  WakeAndTakeKit
//
//  Temporary stand-in until Phase 4c ports offer detail and reserve.
//

import DesignSystem
import SwiftUI

struct OfferDetailPlaceholderView: View {
    let offerID: String

    var body: some View {
        EmptyStateView(
            "Details coming in 4c",
            systemImage: "hammer",
            message: "Offer detail and reserving are being rebuilt. (\(offerID))"
        )
        .navigationTitle("Bag")
        .navigationBarTitleDisplayMode(.inline)
    }
}
