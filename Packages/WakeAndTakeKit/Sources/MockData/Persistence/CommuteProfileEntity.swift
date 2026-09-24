//
//  CommuteProfileEntity.swift
//  WakeAndTakeKit
//

import Domain
import Foundation
import SwiftData

@Model
final class CommuteProfileEntity {
    #Unique<CommuteProfileEntity>([\.key])

    var key: String = singletonKey
    var leaveMinutes: Int
    var arriveMinutes: Int
    var commuteDays: [Int]
    var travelModeRaw: String

    init(_ profile: CommuteProfile) {
        leaveMinutes = profile.leaveMinutes
        arriveMinutes = profile.arriveMinutes
        commuteDays = profile.commuteDays.sorted()
        travelModeRaw = profile.travelMode.rawValue
    }

    func apply(_ profile: CommuteProfile) {
        leaveMinutes = profile.leaveMinutes
        arriveMinutes = profile.arriveMinutes
        commuteDays = profile.commuteDays.sorted()
        travelModeRaw = profile.travelMode.rawValue
    }

    var domain: CommuteProfile {
        CommuteProfile(
            leaveMinutes: leaveMinutes,
            arriveMinutes: arriveMinutes,
            commuteDays: Set(commuteDays),
            travelMode: TravelMode(rawValue: travelModeRaw) ?? .subway
        )
    }
}
