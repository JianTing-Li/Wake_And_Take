//
//  StoreRepositories.swift
//  WalkAndTakeKit
//
//  The stores are the concrete repositories: their actor-isolated methods satisfy
//  the Domain protocols directly, so features only ever see the protocols.
//

import Domain
import Foundation

extension MarketplaceStore: OfferRepository, ReservationRepository, ReviewRepository {}

extension UserDataStore: FavoritesRepository, PreferencesRepository {}
