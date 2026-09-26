//
//  ReservationConfirmationView.swift
//  WalkAndTakeKit
//

import DesignSystem
import SwiftUI

struct ReservationConfirmationView: View {
    let confirmation: ReservationConfirmation
    let onViewOrder: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.splashTeal)
                    .padding(.top, 32)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("You're all set!").font(.title.weight(.bold))
                    Text("Show this code at \(confirmation.restaurantName) when you pick up")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Spacing.m) {
                    Text(confirmation.code)
                        .font(.pickupCode(size: 44))
                        .tracking(8)
                        .accessibilityLabel(
                            "Pickup code \(confirmation.code.map(String.init).joined(separator: " "))"
                        )
                        .accessibilityIdentifier("confirmation.code")
                    QRCodeView(text: confirmation.code, size: 140)
                }
                .padding(.vertical, Spacing.m).padding(.horizontal, Spacing.xxl)
                .background(Color.yolk.opacity(0.25), in: RoundedRectangle(cornerRadius: Radius.panel))

                Text(confirmation.policyText)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(spacing: Spacing.m) {
                    row("When", confirmation.pickupText)
                    row("Where", confirmation.address)
                    row("How", confirmation.pickupInstructions)
                    row("Bags", confirmation.bagsText)
                    row("Total", confirmation.totalText)
                }
                .padding(Spacing.l)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.panel))
            }
            .padding(Spacing.xl)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.s) {
                Button(action: onViewOrder) {
                    Text("View order").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("confirmation.viewOrder")
                Button {
                    dismiss()
                } label: {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .tint(.splashTeal)
            .padding(Spacing.l)
            .background(.bar)
        }
        .presentationDetents([.large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
