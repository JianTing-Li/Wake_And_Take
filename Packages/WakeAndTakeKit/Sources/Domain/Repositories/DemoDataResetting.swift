//
//  DemoDataResetting.swift
//  WakeAndTakeKit
//

import Foundation

/// Wipes every store back to a freshly seeded state and cancels pending alerts.
public protocol DemoDataResetting: Sendable {
    func resetAll() async throws
}
