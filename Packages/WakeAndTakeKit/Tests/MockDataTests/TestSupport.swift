//
//  TestSupport.swift
//  MockDataTests
//

import Domain
import Foundation
import Platform
import SwiftData
import Synchronization

@testable import MockData

enum TestEnv {
    /// The bundled seed (21 restaurants, 32 templates).
    static let seed: Seed = try! SeedLoader.loadBundled()

    /// A New York wall-clock time in September 2026 (Thu the 24th is "today").
    static func sep(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        NYCalendar.date(on: DayKey(rawValue: String(format: "2026-09-%02d", day)), hour: hour, minute: minute)!
    }

    static func offerID(_ templateID: String, day: Int) -> String {
        "\(templateID)-2026-09-\(String(format: "%02d", day))"
    }

    struct Stores {
        let container: ModelContainer
        let marketplace: MarketplaceStore
        let userData: UserDataStore
    }

    /// Fresh in-memory stores sharing one container, rolled over at `now` if given.
    static func makeStores(seed: Seed = seed, rolloverAt now: Date? = nil) async throws -> Stores {
        let container = try ModelContainerFactory.makeInMemory()
        let stores = Stores(
            container: container,
            marketplace: MarketplaceStore(modelContainer: container, seed: seed, codes: SequentialCodes()),
            userData: UserDataStore(modelContainer: container)
        )
        if let now { try await stores.marketplace.rolloverIfNeeded(at: now) }
        return stores
    }

    /// A copy of the seed with a bumped template version and renamed bags.
    static func bumpedSeed(renamingTo name: String) -> Seed {
        var seed = seed
        seed.version.templates += 1
        seed.templates = seed.templates.map {
            var t = $0
            t.name = name
            return t
        }
        return seed
    }
}

/// Predictable pickup codes: AAA2, AAA3, …
final class SequentialCodes: PickupCodeGenerator {
    private let next = Mutex(0)

    func makeCode() -> String {
        let n = next.withLock { value in
            defer { value += 1 }
            return value
        }
        let alphabet = RandomPickupCodeGenerator.alphabet
        return "AAA" + String(alphabet[(n + 24) % alphabet.count])
    }
}

/// Records what the resetter asks of notifications.
final class SpyNotificationScheduler: NotificationScheduler {
    private let calls = Mutex<[String]>([])

    var recorded: [String] { calls.withLock { $0 } }

    func requestPermission() async -> Bool { true }
    func schedule(_ alerts: [OfferAlert], now: Date) async { calls.withLock { $0.append("schedule") } }
    func replaceAll(with alerts: [OfferAlert], now: Date) async { calls.withLock { $0.append("replaceAll") } }
    func cancel(offerIDs: [String]) async { calls.withLock { $0.append("cancel") } }
    func cancelAll() async { calls.withLock { $0.append("cancelAll") } }
    func sendPreview(_ alert: OfferAlert) async { calls.withLock { $0.append("preview") } }
}
