//
//  Clock.swift
//  WalkAndTakeKit
//
//  Business time. Nothing outside `LiveClock` reads `Date.now`.
//  (This shadows the standard library's `Clock` for modules importing Platform.)
//

import Foundation

public protocol Clock: Sendable {
    /// The current time.
    var now: Date { get }

    /// Yields whenever `now` jumps (e.g. debug time travel). The live clock never yields.
    func changes() -> AsyncStream<Void>
}

/// The real time.
public struct LiveClock: Clock {
    public init() {}

    public var now: Date { Date.now }

    public func changes() -> AsyncStream<Void> {
        // Real time only moves forward smoothly; significant time changes are
        // observed separately by the app (UIApplication.significantTimeChangeNotification).
        AsyncStream { _ in }
    }
}
