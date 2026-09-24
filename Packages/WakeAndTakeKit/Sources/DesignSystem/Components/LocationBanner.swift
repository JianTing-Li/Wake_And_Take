//
//  LocationBanner.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// Explains why distances are measured from Long Island City instead of the device.
public struct LocationBanner: View {
    let reason: ResolvedLocation.FallbackReason
    let onOpenSettings: (() -> Void)?

    /// - Parameter onOpenSettings: Shown as a Settings link when permission was denied.
    public init(reason: ResolvedLocation.FallbackReason, onOpenSettings: (() -> Void)? = nil) {
        self.reason = reason
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.splashTeal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.footnote).foregroundStyle(.secondary)
                if reason == .permissionDenied, let onOpenSettings {
                    Button("Turn on location in Settings", action: onOpenSettings)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .background(Color.splashTeal.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.panel))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        reason == .outOfServiceArea ? "mappin.and.ellipse" : "location.slash"
    }

    var title: String {
        reason == .outOfServiceArea ? "Wake&Take is launching in LIC" : "Showing offers near Long Island City"
    }

    var message: String {
        switch reason {
        case .permissionDenied: "Location is off, so distances are from the neighborhood center."
        case .noFix, .unavailable: "We couldn't find your location, so distances are from the neighborhood center."
        case .outOfServiceArea: "You're outside our area for now. Showing offers near Long Island City."
        }
    }
}

#Preview("Light") {
    VStack(spacing: 12) {
        LocationBanner(reason: .permissionDenied) {}
        LocationBanner(reason: .noFix)
        LocationBanner(reason: .outOfServiceArea)
    }
    .padding()
}

#Preview("Dark · large text") {
    LocationBanner(reason: .permissionDenied) {}
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
