//
//  Review.swift
//  WakeAndTakeKit
//

import Foundation

public enum ReviewTag: String, CaseIterable, Identifiable, Codable, Sendable {
    case greatValue, fresh, friendlyStaff, quickPickup, smallPortion, longWait

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .greatValue: "Great value"
        case .fresh: "Fresh"
        case .friendlyStaff: "Friendly staff"
        case .quickPickup: "Quick pickup"
        case .smallPortion: "Not much food"
        case .longWait: "Long wait"
        }
    }

    public var isPositive: Bool { ![.smallPortion, .longWait].contains(self) }
}

/// A customer's rating of a bag they picked up.
public struct Review: Hashable, Codable, Sendable {
    /// 1–5; required.
    public var overall: Int
    /// 0 (not rated) or 1–5.
    public var quality: Int
    public var value: Int
    public var pickup: Int
    public var tags: Set<ReviewTag>
    public var comment: String
    public var submittedAt: Date

    public init(
        overall: Int,
        quality: Int = 0,
        value: Int = 0,
        pickup: Int = 0,
        tags: Set<ReviewTag> = [],
        comment: String = "",
        submittedAt: Date
    ) {
        self.overall = overall
        self.quality = quality
        self.value = value
        self.pickup = pickup
        self.tags = tags
        self.comment = comment
        self.submittedAt = submittedAt
    }
}
