//
//  DiscoverTypes.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import Foundation

public enum DiscoverSortOrder: String, CaseIterable, Identifiable, Sendable {
    case endingSoon = "Ending soon"
    case nearest = "Nearest"
    case cheapest = "Cheapest"

    public var id: String { rawValue }
}

/// One card in the list.
public struct DiscoverItem: Identifiable, Hashable, Sendable {
    public var id: String { offerID }
    public let offerID: String
    public let restaurantID: String
    public let card: BagCard.Content
    public let isFavorite: Bool
}

/// Before 20:00 New York there's one untitled section; after, "Tonight" then "Tomorrow".
public struct DiscoverSection: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case all, tonight, tomorrow
    }

    public var id: Kind { kind }
    public let kind: Kind
    public let items: [DiscoverItem]

    public var title: String? {
        switch kind {
        case .all: nil
        case .tonight: "Tonight"
        case .tomorrow: "Tomorrow"
        }
    }
}

/// The header lines above the list.
public struct DiscoverHeader: Hashable, Sendable {
    public var greetingName: String?
    public var homeArea: String
    public var availableCount: Int
    public var hiddenByPreferencesCount: Int
    public var maxDistanceText: String
    public var hiddenReasonText: String
}

public enum DiscoverMode: Hashable, Sendable {
    case list, map
}
