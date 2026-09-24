//
//  MetadataEntity.swift
//  WakeAndTakeKit
//

import Foundation
import SwiftData

/// Marketplace bookkeeping for rollover and reseeding.
@Model
final class MetadataEntity {
    #Unique<MetadataEntity>([\.key])

    var key: String = singletonKey
    var seedVersion: String?
    var lastGeneratedDayKey: String?

    init() {}
}
