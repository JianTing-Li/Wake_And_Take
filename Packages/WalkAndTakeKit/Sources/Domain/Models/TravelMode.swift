//
//  TravelMode.swift
//  WalkAndTakeKit
//
//  Symbols live in DesignSystem (TravelMode+Style).
//

import Foundation

public enum TravelMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case walk, subway, bike, drive

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .walk: "Walk"
        case .subway: "Subway"
        case .bike: "Bike"
        case .drive: "Drive"
        }
    }
}
