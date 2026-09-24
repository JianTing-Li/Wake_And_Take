//
//  CommuteProfile.swift
//  WakeAndTakeKit
//

import Foundation

/// The customer's morning routine.
public struct CommuteProfile: Hashable, Codable, Sendable {
    /// Minutes after midnight, New York time.
    public var leaveMinutes: Int
    public var arriveMinutes: Int
    /// Calendar weekdays (1 = Sunday … 7 = Saturday).
    public var commuteDays: Set<Int>
    public var travelMode: TravelMode

    public init(
        leaveMinutes: Int = 7 * 60 + 30,
        arriveMinutes: Int = 8 * 60 + 30,
        commuteDays: Set<Int> = [2, 3, 4, 5, 6],
        travelMode: TravelMode = .subway
    ) {
        self.leaveMinutes = leaveMinutes
        self.arriveMinutes = arriveMinutes
        self.commuteDays = commuteDays
        self.travelMode = travelMode
    }

    public var isValid: Bool { arriveMinutes > leaveMinutes }
}
