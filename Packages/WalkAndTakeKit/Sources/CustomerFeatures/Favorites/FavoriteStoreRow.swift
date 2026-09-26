//
//  FavoriteStoreRow.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import SwiftUI

struct FavoriteStoreRow: View {
    let row: FavoritesModel.Row
    let showsBell: Bool
    let onToggleAlerts: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            CategoryTile(category: row.category)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name).font(.headline)
                statusText
            }

            Spacer(minLength: 8)

            if showsBell {
                Button(action: onToggleAlerts) {
                    Image(systemName: row.alertsOn ? "bell.fill" : "bell.slash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(row.alertsOn ? Color.splashTeal : .secondary)
                        .frame(width: 40, height: 40)
                        .background(
                            row.alertsOn ? Color.splashTeal.opacity(0.15) : Color(.tertiarySystemFill), in: Circle()
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .sensoryFeedback(.selection, trigger: row.alertsOn)
                .accessibilityLabel(row.alertsOn ? "Turn off alerts for \(row.name)" : "Turn on alerts for \(row.name)")
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusText: some View {
        switch row.status {
        case .availableNow(let text):
            Label(text, systemImage: "bag.fill").foregroundStyle(Color.splashTeal)
                .font(.caption.weight(.semibold))
        case .upcoming(let text):
            Label(text, systemImage: "clock").foregroundStyle(.orange)
                .font(.caption.weight(.semibold))
        case .none:
            Text("No bags left today").foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
