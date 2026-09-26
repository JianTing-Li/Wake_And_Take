//
//  Impact.swift
//  WalkAndTakeKit
//

import Foundation

/// Running totals for bags a customer has actually collected.
public struct Impact: Hashable, Sendable {
    public var bagsRescued: Int
    public var moneySaved: Money
    /// Estimated CO₂e avoided, in kg.
    public var co2eAvoidedKg: Double

    public init(bagsRescued: Int = 0, moneySaved: Money = .zero, co2eAvoidedKg: Double = 0) {
        self.bagsRescued = bagsRescued
        self.moneySaved = moneySaved
        self.co2eAvoidedKg = co2eAvoidedKg
    }
}
