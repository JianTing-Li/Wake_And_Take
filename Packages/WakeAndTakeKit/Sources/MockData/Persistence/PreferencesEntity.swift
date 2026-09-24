//
//  PreferencesEntity.swift
//  WakeAndTakeKit
//
//  Singleton rows are keyed by `singletonKey`.
//

import Domain
import Foundation
import SwiftData

/// Key shared by the single-row entities.
let singletonKey = "singleton"

@Model
final class PreferencesEntity {
    #Unique<PreferencesEntity>([\.key])

    var key: String = singletonKey
    var name: String
    var homeArea: String
    var maxDistanceMiles: Double
    var dietaryRaw: [String]

    init(_ preferences: UserPreferences) {
        name = preferences.name
        homeArea = preferences.homeArea
        maxDistanceMiles = preferences.maxDistanceMiles
        dietaryRaw = preferences.dietary.map(\.rawValue).sorted()
    }

    func apply(_ preferences: UserPreferences) {
        name = preferences.name
        homeArea = preferences.homeArea
        maxDistanceMiles = preferences.maxDistanceMiles
        dietaryRaw = preferences.dietary.map(\.rawValue).sorted()
    }

    var domain: UserPreferences {
        UserPreferences(
            name: name,
            homeArea: homeArea,
            maxDistanceMiles: maxDistanceMiles,
            dietary: Set(dietaryRaw.compactMap(DietaryTag.init(rawValue:)))
        )
    }
}
