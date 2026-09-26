//
//  FlowTags.swift
//  WalkAndTakeKit
//

import Domain
import SwiftUI

/// Toggleable chips for quick review feedback.
public struct FlowTags: View {
    @Binding var selection: Set<ReviewTag>

    public init(selection: Binding<Set<ReviewTag>>) {
        _selection = selection
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(ReviewTag.allCases) { tag in
                let isOn = selection.contains(tag)
                Button {
                    if isOn { selection.remove(tag) } else { selection.insert(tag) }
                } label: {
                    Label(tag.label, systemImage: tag.isPositive ? "hand.thumbsup" : "hand.thumbsdown")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isOn ? Color.splashTeal : Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

#Preview("Light") {
    @Previewable @State var tags: Set<ReviewTag> = [.fresh, .longWait]
    FlowTags(selection: $tags).padding()
}

#Preview("Dark") {
    @Previewable @State var tags: Set<ReviewTag> = [.greatValue]
    FlowTags(selection: $tags).padding().preferredColorScheme(.dark)
}

#Preview("Large text") {
    @Previewable @State var tags: Set<ReviewTag> = [.quickPickup]
    FlowTags(selection: $tags).padding().dynamicTypeSize(.accessibility2)
}
