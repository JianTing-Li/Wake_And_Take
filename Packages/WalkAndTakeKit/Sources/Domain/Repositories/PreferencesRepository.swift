//
//  PreferencesRepository.swift
//  WalkAndTakeKit
//

import Foundation

/// The customer's preferences and commute. Missing values read as defaults.
public protocol PreferencesRepository: Sendable {
    func preferences() async throws -> UserPreferences
    func updatePreferences(_ preferences: UserPreferences) async throws
    func commuteProfile() async throws -> CommuteProfile
    func updateCommuteProfile(_ profile: CommuteProfile) async throws
    func changes() -> AsyncStream<UserDataChange>
}
