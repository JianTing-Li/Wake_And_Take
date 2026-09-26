//
//  SplashView.swift
//  WalkAndTake
//

import DesignSystem
import SwiftUI

/// Launch splash: a walker strides in, crouches to grab a rescue bag,
/// and heads off with it swinging before the app appears.
struct SplashView: View {
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var pickedUp = false

    var body: some View {
        ZStack {
            Color.splashTeal.ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let elapsed = start.map { timeline.date.timeIntervalSince($0) } ?? 0

                VStack(spacing: 28) {
                    Canvas { ctx, size in
                        ctx.scaleBy(x: WalkScene.scale, y: WalkScene.scale)
                        WalkScene(time: reduceMotion ? WalkScene.standingWithBag : elapsed)
                            .draw(in: &ctx, size: CGSize(width: size.width / WalkScene.scale, height: size.height / WalkScene.scale))
                    } symbols: {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.splashTeal)
                            .tag(WalkScene.leafSymbol)
                    }
                    .frame(height: 270)

                    title(progress: reduceMotion ? elapsed / 0.4 : (elapsed - WalkScene.titleStart) / 0.45)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Walk & Take")
        .sensoryFeedback(.impact(weight: .light), trigger: pickedUp)
        .onAppear { start = .now }
        .task { await play() }
    }

    private func title(progress: Double) -> some View {
        let p = WalkScene.easeOut(progress)
        return VStack(spacing: 8) {
            Text("Walk & Take")
                .font(.brand(size: 40, weight: .heavy))
                .foregroundStyle(Color.shellCream)
            Text("Step out. Rescue good food.")
                .font(.brand(size: 17, weight: .semibold))
                .foregroundStyle(Color.yolk)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .opacity(p)
        .offset(y: (1 - p) * 16)
    }

    // MARK: - Timeline

    private func play() async {
        if reduceMotion {
            await pause(1.8)
            onFinished()
            return
        }
        await pause(WalkScene.crouchPeak)
        pickedUp = true
        await pause(WalkScene.finish - WalkScene.crouchPeak)
        onFinished()
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

// MARK: - Scene

/// Draws one frame of the walk-and-grab animation at a given time.
struct WalkScene {
    let time: Double

    static let leafSymbol = 0
    /// Scene units are drawn this much larger on screen.
    static let scale: CGFloat = 1.5

    // Beats, in seconds.
    static let walkInEnd = 1.25
    static let crouchPeak = 1.5
    static let standUp = 1.72
    static let walkOutEnd = 2.9
    static let titleStart = 2.1
    static let finish = 3.5
    static let standingWithBag = standUp

    private var figureColor: Color { .shellCream }
    private var farColor: Color { .shellCream.opacity(0.5) }
    private var bagColor: Color { .yolk }
    private let bagWidth: CGFloat = 30
    private let handleHeight: CGFloat = 8
    /// Roughly one full stride (two steps) at this leg length.
    private let targetStride: CGFloat = 80

    func draw(in ctx: inout GraphicsContext, size: CGSize) {
        let groundY = size.height - 24
        let bagX = size.width * 0.58

        drawGround(in: &ctx, width: size.width, y: groundY)

        // The crouch decides where the walker stops and how tall the bag is,
        // so the hand lands exactly on the handle.
        let crouch = Skeleton(pose: .crouch).grounded(at: groundY)
        let bagHeight = groundY - crouch.hand[1].y - handleHeight
        let groundAnchor = CGPoint(x: bagX, y: crouch.hand[1].y)

        let startX: CGFloat = -40
        let stopX = bagX - crouch.hand[1].x
        let distanceIn = stopX - startX
        // Half-cycle count so the legs are together when the walker stops.
        let cycles = max(1, (distanceIn / targetStride * 2).rounded() / 2)
        let stride = distanceIn / cycles
        let endX = size.width + 60

        var hipX: CGFloat
        var pose: Pose
        let carrying = time >= Self.crouchPeak

        switch time {
        case ..<Self.walkInEnd:
            let u = Self.clamp(time / Self.walkInEnd)
            hipX = startX + distanceIn * u * (2 - u)
            pose = .walking(phase: 2 * .pi * (hipX - startX) / stride, carrying: false)
        case ..<Self.standUp:
            hipX = stopX
            let down = time < Self.crouchPeak
            let c = down
                ? Self.smooth((time - Self.walkInEnd) / (Self.crouchPeak - Self.walkInEnd))
                : Self.smooth(1 - (time - Self.crouchPeak) / (Self.standUp - Self.crouchPeak))
            pose = Pose.walking(phase: 2 * .pi * cycles, carrying: carrying).mixed(with: .crouch, c)
        default:
            let u = Self.clamp((time - Self.standUp) / (Self.walkOutEnd - Self.standUp))
            hipX = stopX + (endX - stopX) * pow(u, 1.5)
            pose = .walking(phase: 2 * .pi * (cycles + (hipX - stopX) / stride), carrying: true)
        }

        var body = Skeleton(pose: pose).grounded(at: groundY)
        body.offset(dx: hipX, dy: 0)

        if !carrying {
            drawBag(in: &ctx, anchor: groundAnchor, height: bagHeight, swing: 0)
        }

        // Far limbs first, then torso, then near limbs for depth.
        stroke(&ctx, [body.shoulder, body.elbow[0], body.hand[0]], farColor, 7)
        stroke(&ctx, [body.hip, body.knee[0], body.foot[0]], farColor, 8)
        stroke(&ctx, [body.hip, body.shoulder], figureColor, 9)
        ctx.fill(Path(ellipseIn: CGRect(x: body.head.x - 10, y: body.head.y - 10, width: 20, height: 20)),
                 with: .color(figureColor))
        stroke(&ctx, [body.hip, body.knee[1], body.foot[1]], figureColor, 8)

        if carrying {
            drawBag(in: &ctx, anchor: body.hand[1], height: bagHeight, swing: -pose.upperArm[1] * 1.3)
        }
        stroke(&ctx, [body.shoulder, body.elbow[1], body.hand[1]], figureColor, 7)
    }

    private func drawGround(in ctx: inout GraphicsContext, width: CGFloat, y: CGFloat) {
        let p = Self.easeOut(time / 0.4)
        var line = Path()
        line.move(to: CGPoint(x: width / 2 * (1 - p), y: y + 6))
        line.addLine(to: CGPoint(x: width / 2 * (1 + p), y: y + 6))
        ctx.stroke(line, with: .color(Color.shellCream.opacity(0.9)),
                   style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }

    /// `anchor` is the top of the handle; the bag hangs below it, rotated by `swing` degrees.
    private func drawBag(in ctx: inout GraphicsContext, anchor: CGPoint, height: CGFloat, swing: Double) {
        var bag = ctx
        bag.translateBy(x: anchor.x, y: anchor.y)
        bag.rotate(by: .degrees(swing))

        var handle = Path()
        handle.move(to: CGPoint(x: -7, y: handleHeight + 2))
        handle.addQuadCurve(to: CGPoint(x: 7, y: handleHeight + 2), control: CGPoint(x: 0, y: -handleHeight))
        bag.stroke(handle, with: .color(bagColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let rect = CGRect(x: -bagWidth / 2, y: handleHeight, width: bagWidth, height: height)
        bag.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(bagColor))
        if let leaf = bag.resolveSymbol(id: Self.leafSymbol) {
            bag.draw(leaf, at: CGPoint(x: rect.midX, y: rect.midY + 1))
        }
    }

    private func stroke(_ ctx: inout GraphicsContext, _ points: [CGPoint], _ color: Color, _ width: CGFloat) {
        var path = Path()
        path.addLines(points)
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    // MARK: Easing

    static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    static func smooth(_ x: Double) -> Double { let u = clamp(x); return u * u * (3 - 2 * u) }
    static func easeOut(_ x: Double) -> Double { let u = clamp(x); return 1 - (1 - u) * (1 - u) }
}

// MARK: - Figure

/// Joint angles in degrees. Limbs are measured forward of straight down,
/// the torso forward of straight up. Index 0 is the far side, 1 the near side.
nonisolated struct Pose {
    var lean: Double
    var thigh: [Double]
    var shin: [Double]
    var upperArm: [Double]
    var forearm: [Double]

    static func walking(phase: Double, carrying: Bool) -> Pose {
        let s = sin(phase)
        let legPhases = [phase + .pi, phase]
        let thigh = [-28 * s, 28 * s]
        // A knee bends while its leg swings forward.
        let shin = zip(thigh, legPhases).map { $0 - 40 * max(0, cos($1)) }
        var arm = [24 * s, -24 * s]
        var forearm = arm.map { $0 + 25 }
        if carrying {
            arm[1] = -6 * s
            forearm[1] = arm[1] + 4
        }
        return Pose(lean: 6, thigh: thigh, shin: shin, upperArm: arm, forearm: forearm)
    }

    static let crouch = Pose(lean: 35, thigh: [45, 45], shin: [-15, -15], upperArm: [10, 25], forearm: [20, 15])

    func mixed(with other: Pose, _ k: Double) -> Pose {
        func mix(_ a: [Double], _ b: [Double]) -> [Double] { zip(a, b).map { $0 + ($1 - $0) * k } }
        return Pose(lean: lean + (other.lean - lean) * k,
                    thigh: mix(thigh, other.thigh), shin: mix(shin, other.shin),
                    upperArm: mix(upperArm, other.upperArm), forearm: mix(forearm, other.forearm))
    }
}

/// Joint positions for a pose, starting with the hip at the origin.
nonisolated struct Skeleton {
    var hip = CGPoint.zero
    var knee: [CGPoint], foot: [CGPoint]
    var shoulder: CGPoint, head: CGPoint
    var elbow: [CGPoint], hand: [CGPoint]

    private static let thigh: CGFloat = 22, shin: CGFloat = 22
    private static let torso: CGFloat = 34, neck: CGFloat = 14
    private static let upperArm: CGFloat = 17, forearm: CGFloat = 17

    init(pose: Pose) {
        func limb(_ from: CGPoint, _ length: CGFloat, _ degrees: Double) -> CGPoint {
            let r = degrees * .pi / 180
            return CGPoint(x: from.x + length * sin(r), y: from.y + length * cos(r))
        }
        func up(_ length: CGFloat) -> CGPoint {
            let r = pose.lean * .pi / 180
            return CGPoint(x: length * sin(r), y: -length * cos(r))
        }
        let knee = pose.thigh.map { limb(.zero, Self.thigh, $0) }
        self.knee = knee
        foot = zip(knee, pose.shin).map { limb($0, Self.shin, $1) }
        let shoulder = up(Self.torso)
        self.shoulder = shoulder
        head = up(Self.torso + Self.neck)
        elbow = pose.upperArm.map { limb(shoulder, Self.upperArm, $0) }
        hand = zip(elbow, pose.forearm).map { limb($0, Self.forearm, $1) }
    }

    /// Shifts the body so the lower foot rests on the ground.
    func grounded(at groundY: CGFloat) -> Skeleton {
        var s = self
        s.offset(dx: 0, dy: groundY - max(foot[0].y, foot[1].y))
        return s
    }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        func move(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + dx, y: p.y + dy) }
        hip = move(hip)
        knee = knee.map(move); foot = foot.map(move)
        shoulder = move(shoulder); head = move(head)
        elbow = elbow.map(move); hand = hand.map(move)
    }
}

#Preview {
    SplashView()
}
