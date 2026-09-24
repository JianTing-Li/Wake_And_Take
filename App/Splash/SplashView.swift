//
//  SplashView.swift
//  WakeAndTake
//

import DesignSystem
import SwiftUI

/// Launch splash: a cream egg on deep teal wobbles, cracks open,
/// and the yolk rises like a morning sun before the app appears.
struct SplashView: View {
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .hidden
    @State private var wobbles = 0
    @State private var raysSpinning = false

    private enum Phase: Int, Comparable {
        case hidden, appear, crack, open, title
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    private let eggWidth: CGFloat = 150
    private var eggHeight: CGFloat { eggWidth * 1.3 }

    var body: some View {
        ZStack {
            Color.splashTeal.ignoresSafeArea()

            VStack(spacing: 36) {
                egg
                    .frame(width: eggWidth, height: eggHeight)
                    .scaleEffect(phase >= .appear ? 1 : 0.6)
                    .opacity(phase >= .appear ? 1 : 0)
                    .keyframeAnimator(initialValue: 0.0, trigger: wobbles) { content, angle in
                        content.rotationEffect(.degrees(angle), anchor: .bottom)
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(-9, duration: 0.12)
                            CubicKeyframe(8, duration: 0.14)
                            CubicKeyframe(-6, duration: 0.12)
                            CubicKeyframe(4, duration: 0.10)
                            CubicKeyframe(0, duration: 0.10)
                        }
                    }

                VStack(spacing: 8) {
                    Text("Wake & Take")
                        .font(.brand(size: 40, weight: .heavy))
                        .foregroundStyle(Color.shellCream)
                    Text("Rescue breakfast on your way")
                        .font(.brand(size: 17, weight: .semibold))
                        .foregroundStyle(Color.yolk)
                }
                .opacity(phase >= .title ? 1 : 0)
                .offset(y: phase >= .title ? 0 : 16)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: phase == .crack)
        .task { await play() }
    }

    // MARK: - Egg

    private var egg: some View {
        ZStack {
            // Sun rays behind the yolk
            rays
                .offset(y: phase >= .open ? -eggHeight * 0.3 : 0)
                .opacity(phase >= .open ? 1 : 0)
                .scaleEffect(phase >= .open ? 1 : 0.4)

            // Yolk sits inside the shell, then rises out of it
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1, green: 0.86, blue: 0.35), .yolk],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: eggWidth * 0.4
                    )
                )
                .frame(width: eggWidth * 0.62)
                .offset(y: phase >= .open ? -eggHeight * 0.3 : eggHeight * 0.12)
                .scaleEffect(phase >= .open ? 1.1 : 0.9)

            // Bottom shell
            EggShape()
                .fill(shellGradient)
                .mask(ShellHalf(side: .bottom))
                .offset(y: phase >= .open ? 10 : 0)

            // Whole egg hides the seam between the halves until it breaks
            EggShape()
                .fill(shellGradient)
                .opacity(phase >= .open ? 0 : 1)
                .animation(nil, value: phase)

            // Top shell flies off
            EggShape()
                .fill(shellGradient)
                .mask(ShellHalf(side: .top))
                .rotationEffect(.degrees(phase >= .open ? -38 : 0), anchor: .bottomLeading)
                .offset(x: phase >= .open ? -40 : 0, y: phase >= .open ? -130 : 0)
                .opacity(phase >= .open ? 0 : 1)

            // Crack line draws across the shell
            CrackLine()
                .trim(from: 0, to: phase >= .crack ? 1 : 0)
                .stroke(Color.splashTeal, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .opacity(phase >= .open ? 0 : 1)
        }
    }

    private var rays: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color.yolk.opacity(0.85))
                    .frame(width: 6, height: 22)
                    .offset(y: -eggWidth * 0.55)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
        .rotationEffect(.degrees(raysSpinning ? 30 : 0))
    }

    private var shellGradient: LinearGradient {
        LinearGradient(
            colors: [.shellCream, Color(red: 0.93, green: 0.87, blue: 0.76)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Timeline

    private func play() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.4)) { phase = .title }
            await pause(1.4)
            onFinished()
            return
        }

        withAnimation(.spring(duration: 0.5, bounce: 0.4)) { phase = .appear }
        await pause(0.55)
        wobbles += 1
        await pause(0.65)
        withAnimation(.easeOut(duration: 0.25)) { phase = .crack }
        await pause(0.35)
        withAnimation(.spring(duration: 0.8, bounce: 0.35)) { phase = .open }
        withAnimation(.linear(duration: 3)) { raysSpinning = true }
        await pause(0.45)
        withAnimation(.easeOut(duration: 0.5)) { phase = .title }
        await pause(1.4)
        onFinished()
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

// MARK: - Shapes

nonisolated struct EggShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0.5 * w, y: 0))
        p.addCurve(to: CGPoint(x: w, y: 0.62 * h),
                   control1: CGPoint(x: 0.82 * w, y: 0),
                   control2: CGPoint(x: w, y: 0.3 * h))
        p.addCurve(to: CGPoint(x: 0.5 * w, y: h),
                   control1: CGPoint(x: w, y: 0.88 * h),
                   control2: CGPoint(x: 0.78 * w, y: h))
        p.addCurve(to: CGPoint(x: 0, y: 0.62 * h),
                   control1: CGPoint(x: 0.22 * w, y: h),
                   control2: CGPoint(x: 0, y: 0.88 * h))
        p.addCurve(to: CGPoint(x: 0.5 * w, y: 0),
                   control1: CGPoint(x: 0, y: 0.3 * h),
                   control2: CGPoint(x: 0.18 * w, y: 0))
        return p.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// Zigzag points (in unit space) where the shell splits.
nonisolated private let crackPoints: [CGPoint] = [
    CGPoint(x: -0.05, y: 0.50), CGPoint(x: 0.12, y: 0.44), CGPoint(x: 0.26, y: 0.54),
    CGPoint(x: 0.40, y: 0.45), CGPoint(x: 0.53, y: 0.55), CGPoint(x: 0.66, y: 0.46),
    CGPoint(x: 0.80, y: 0.54), CGPoint(x: 0.92, y: 0.46), CGPoint(x: 1.05, y: 0.51),
]

nonisolated private func scaled(_ p: CGPoint, in rect: CGRect) -> CGPoint {
    CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
}

nonisolated struct CrackLine: Shape {
    func path(in rect: CGRect) -> Path {
        // Keep the visible crack inside the egg outline.
        let inset = crackPoints.dropFirst().dropLast()
        var p = Path()
        p.addLines(inset.map { scaled($0, in: rect) })
        return p
    }
}

nonisolated struct ShellHalf: Shape {
    enum Side { case top, bottom }
    var side: Side

    func path(in rect: CGRect) -> Path {
        let zig = crackPoints.map { scaled($0, in: rect) }
        let pad = rect.height
        var p = Path()
        switch side {
        case .top:
            p.move(to: CGPoint(x: rect.minX - pad, y: rect.minY - pad))
            p.addLine(to: CGPoint(x: rect.maxX + pad, y: rect.minY - pad))
            p.addLine(to: CGPoint(x: rect.maxX + pad, y: zig.last!.y))
            zig.reversed().forEach { p.addLine(to: $0) }
            p.addLine(to: CGPoint(x: rect.minX - pad, y: zig.first!.y))
        case .bottom:
            p.move(to: CGPoint(x: rect.minX - pad, y: zig.first!.y))
            zig.forEach { p.addLine(to: $0) }
            p.addLine(to: CGPoint(x: rect.maxX + pad, y: zig.last!.y))
            p.addLine(to: CGPoint(x: rect.maxX + pad, y: rect.maxY + pad))
            p.addLine(to: CGPoint(x: rect.minX - pad, y: rect.maxY + pad))
        }
        p.closeSubpath()
        return p
    }
}

#Preview {
    SplashView()
}
