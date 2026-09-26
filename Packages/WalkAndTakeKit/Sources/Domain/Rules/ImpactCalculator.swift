//
//  ImpactCalculator.swift
//  WalkAndTakeKit
//

import Foundation

public enum ImpactCalculator {
    /// Rough estimate of CO₂e avoided per rescued bag, in kg.
    public static let co2ePerBagKg = 2.5

    /// Totals for collected reservations only; cancelled, missed and active ones don't count.
    public static func impact(of reservations: [Reservation]) -> Impact {
        reservations.filter { $0.collectedAt != nil }.reduce(into: Impact()) { total, r in
            total.bagsRescued += r.quantity
            total.moneySaved += r.savings
            total.co2eAvoidedKg += co2e(forBags: r.quantity)
        }
    }

    public static func co2e(forBags bags: Int) -> Double {
        Double(bags) * co2ePerBagKg
    }
}
