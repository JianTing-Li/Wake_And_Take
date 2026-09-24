//
//  DayKey.swift
//  WakeAndTakeKit
//

import Foundation

/// A calendar day as "yyyy-MM-dd", e.g. the New York day an offer belongs to.
/// Keys sort in date order.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The day `date` falls on in `calendar`'s time zone.
    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public var description: String { rawValue }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.rawValue < rhs.rawValue }
}
