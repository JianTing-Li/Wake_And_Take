//
//  SwipeToConfirm.swift
//  WakeAndTakeKit
//

import SwiftUI

/// A slide-to-confirm control so pickup isn't confirmed by an accidental tap.
public struct SwipeToConfirm: View {
    let title: String
    let action: () -> Void

    @State private var offset: CGFloat = 0
    @State private var confirmed = false
    private let knob: CGFloat = 56

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        GeometryReader { geo in
            let maxOffset = max(geo.size.width - knob - 8, 1)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.splashTeal.opacity(0.15))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.splashTeal)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .opacity(1 - offset / maxOffset)

                Circle()
                    .fill(Color.splashTeal)
                    .frame(width: knob, height: knob)
                    .overlay {
                        Image(systemName: confirmed ? "checkmark" : "chevron.right.2")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4 + offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !confirmed else { return }
                                offset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                guard !confirmed else { return }
                                if offset > maxOffset * 0.85 {
                                    withAnimation(.spring(duration: 0.3)) { offset = maxOffset }
                                    confirm()
                                } else {
                                    withAnimation(.spring(duration: 0.3)) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: knob + 8)
        .sensoryFeedback(.success, trigger: confirmed)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirm() }
    }

    private func confirm() {
        guard !confirmed else { return }
        confirmed = true
        action()
    }
}

#Preview("Light") {
    SwipeToConfirm(title: "Swipe to confirm pickup") {}.padding()
}

#Preview("Dark · large text") {
    SwipeToConfirm(title: "Swipe to confirm pickup") {}
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
