//
//  MarketplaceChange.swift
//  WakeAndTakeKit
//

import Foundation

/// Emitted by the marketplace after every committed mutation.
public enum MarketplaceChange: Hashable, Sendable {
    /// An offer's stock changed (reserve, change quantity, cancel).
    case stockChanged(offerID: String)
    /// A reservation was created or updated.
    case reservationsChanged
    /// A review changed a restaurant's rating.
    case ratingChanged(restaurantID: String)
    /// Offers were generated or pruned for a new day (or the seed changed).
    case rolledOver
    /// All demo data was wiped and reseeded.
    case reset
}

/// Emitted by user data after every committed mutation.
public enum UserDataChange: Hashable, Sendable {
    case favoritesChanged
    case preferencesChanged
    case commuteChanged
    case reset
}
