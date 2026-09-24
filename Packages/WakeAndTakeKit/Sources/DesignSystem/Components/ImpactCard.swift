//
//  ImpactCard.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// Teal banner with bags rescued, money saved, and CO₂e avoided.
public struct ImpactCard: View {
    let impact: Impact

    public init(impact: Impact) {
        self.impact = impact
    }

    public var body: some View {
        HStack(spacing: 0) {
            stat("\(impact.bagsRescued)", "bags rescued", symbol: "bag.fill")
            Divider().frame(height: 44).overlay(Color.white.opacity(0.3))
            stat(impact.moneySaved.usd, "saved", symbol: "dollarsign.circle.fill")
            Divider().frame(height: 44).overlay(Color.white.opacity(0.3))
            stat(String(format: "%.1f kg", impact.co2eAvoidedKg), "CO₂e avoided", symbol: "leaf.fill")
        }
        .padding(.vertical, Spacing.l)
        .foregroundStyle(.white)
        .background(Color.splashTeal, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(Color.yolk)
            Text(value).font(.title3.weight(.bold)).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption).opacity(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Light") {
    ImpactCard(impact: Impact(bagsRescued: 7, moneySaved: Money(cents: 8423), co2eAvoidedKg: 17.5)).padding()
}

#Preview("Dark") {
    ImpactCard(impact: Impact()).padding().preferredColorScheme(.dark)
}

#Preview("Large text") {
    ImpactCard(impact: Impact(bagsRescued: 12, moneySaved: Money(cents: 14_210), co2eAvoidedKg: 30))
        .padding()
        .dynamicTypeSize(.accessibility2)
}
