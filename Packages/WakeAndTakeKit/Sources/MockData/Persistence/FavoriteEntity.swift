//
//  FavoriteEntity.swift
//  WakeAndTakeKit
//

import Domain
import Foundation
import SwiftData

@Model
final class FavoriteEntity {
    #Unique<FavoriteEntity>([\.restaurantID])

    var restaurantID: String
    var alertsEnabled: Bool

    init(restaurantID: String, alertsEnabled: Bool) {
        self.restaurantID = restaurantID
        self.alertsEnabled = alertsEnabled
    }

    var domain: FavoriteRestaurant {
        FavoriteRestaurant(restaurantID: restaurantID, alertsEnabled: alertsEnabled)
    }
}
