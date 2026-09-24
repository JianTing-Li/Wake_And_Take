//
//  TravelMode+Style.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

extension TravelMode {
    public var symbol: String {
        switch self {
        case .walk: "figure.walk"
        case .subway: "tram.fill"
        case .bike: "bicycle"
        case .drive: "car.fill"
        }
    }
}
