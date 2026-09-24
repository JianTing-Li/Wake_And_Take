//
//  PickupWindow.swift
//  WakeAndTakeKit
//

import Foundation

/// When a bag can be collected. Seed windows are short, same-day, and end by 23:59.
public struct PickupWindow: Hashable, Codable, Sendable {
    public var start: Date
    public var end: Date

    /// Longest window a template may define.
    public static let maxDuration: TimeInterval = 3.5 * 60 * 60

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public func hasStarted(at now: Date) -> Bool { now >= start }
    public func hasEnded(at now: Date) -> Bool { now >= end }
    public func isOpen(at now: Date) -> Bool { hasStarted(at: now) && !hasEnded(at: now) }
}
