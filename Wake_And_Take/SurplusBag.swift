//
//  SurplusBag.swift
//  Wake_And_Take
//

import SwiftUI
import CoreLocation

enum FoodCategory: String, CaseIterable, Identifiable {
    case bakery = "Bakery"
    case coffee = "Coffee"
    case breakfast = "Breakfast"
    case grocery = "Grocery"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .bakery: "birthday.cake.fill"
        case .coffee: "cup.and.saucer.fill"
        case .breakfast: "takeoutbag.and.cup.and.straw.fill"
        case .grocery: "basket.fill"
        }
    }

    var tint: Color {
        switch self {
        case .bakery: Color(red: 0.80, green: 0.52, blue: 0.25)
        case .coffee: Color(red: 0.45, green: 0.30, blue: 0.22)
        case .breakfast: Color(red: 0.93, green: 0.55, blue: 0.20)
        case .grocery: Color(red: 0.30, green: 0.60, blue: 0.35)
        }
    }
}

/// A surprise bag of surplus food a store has listed for pickup.
struct SurplusBag: Identifiable {
    let id = UUID()
    let name: String
    let store: String
    let category: FoodCategory
    let address: String
    let distanceMiles: Double
    let rating: Double
    let originalPrice: Double
    let price: Double
    let pickupStart: Date
    let pickupEnd: Date
    var bagsLeft: Int
    let details: String
    /// Diets every item in this bag suits.
    var dietary: Set<DietaryTag> = []
    var latitude = 40.7465
    var longitude = -73.9420

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isSoldOut: Bool { bagsLeft == 0 }

    func hasEnded(at now: Date) -> Bool { now >= pickupEnd }

    func isAvailable(at now: Date) -> Bool { !isSoldOut && !hasEnded(at: now) }

    var pickupWindow: String {
        "\(pickupStart.formatted(date: .omitted, time: .shortened)) – \(pickupEnd.formatted(date: .omitted, time: .shortened))"
    }

    /// Short status for how urgent the pickup is, e.g. "Ends in 25 min".
    func urgency(at now: Date) -> String {
        isSoldOut ? "Sold out" : pickupCountdown(at: now)
    }

    /// Where `now` falls in the pickup window, ignoring stock.
    func pickupCountdown(at now: Date) -> String {
        if hasEnded(at: now) { return "Pickup ended" }
        if now < pickupStart {
            return "Opens at \(pickupStart.formatted(date: .omitted, time: .shortened))"
        }
        let minutes = Int(pickupEnd.timeIntervalSince(now) / 60)
        if minutes < 60 { return "Ends in \(max(minutes, 1)) min" }
        return "Ends at \(pickupEnd.formatted(date: .omitted, time: .shortened))"
    }

    func endsSoon(at now: Date) -> Bool {
        isAvailable(at: now) && now >= pickupStart && pickupEnd.timeIntervalSince(now) < 30 * 60
    }

    var savingsPercent: Int {
        Int(((originalPrice - price) / originalPrice * 100).rounded())
    }
}

enum CancelReason: String, CaseIterable, Identifiable {
    case plansChanged = "My plans changed"
    case tooFar = "It's out of my way"
    case orderedByMistake = "I ordered by mistake"
    case other = "Other"

    var id: String { rawValue }
}

struct Reservation: Identifiable {
    let id = UUID()
    let bag: SurplusBag
    var quantity: Int
    let pickupCode: String
    let reservedAt: Date
    var collectedAt: Date?
    var cancelledAt: Date?
    var cancelReason: CancelReason?

    var total: Double { bag.price * Double(quantity) }
    var savings: Double { (bag.originalPrice - bag.price) * Double(quantity) }

    /// How long before pickup ends changes are still allowed,
    /// so the store isn't left with a bag it already packed.
    static let changeCutoff: TimeInterval = 10 * 60
    static let maxQuantity = 3

    var changeDeadline: Date { bag.pickupEnd.addingTimeInterval(-Self.changeCutoff) }

    enum Status { case upcoming, readyNow, collected, missed, cancelled }

    func status(at now: Date) -> Status {
        if cancelledAt != nil { return .cancelled }
        if collectedAt != nil { return .collected }
        if now >= bag.pickupEnd { return .missed }
        if now >= bag.pickupStart { return .readyNow }
        return .upcoming
    }

    func isActive(at now: Date) -> Bool {
        let s = status(at: now)
        return s == .upcoming || s == .readyNow
    }

    func canChange(at now: Date) -> Bool {
        isActive(at: now) && now < changeDeadline
    }
}

/// Running totals for bags a customer has actually collected.
struct Impact {
    var bagsRescued = 0
    var moneySaved = 0.0

    /// Rough estimate of CO2e avoided per rescued bag, in kg.
    static let co2ePerBag = 2.5
    var co2eAvoided: Double { Double(bagsRescued) * Self.co2ePerBag }
}

@Observable
final class BagStore {
    var bags: [SurplusBag]
    private(set) var reservations: [Reservation] = []

    /// Store names the customer saved, kept across launches.
    private(set) var favoriteStores: Set<String> {
        didSet { defaults.set(Array(favoriteStores), forKey: "favoriteStores") }
    }
    /// Favorite stores the customer wants alerts from.
    private(set) var alertStores: Set<String> {
        didSet { defaults.set(Array(alertStores), forKey: "alertStores") }
    }

    /// Commute and dietary preferences, kept across launches.
    var profile: CommuteProfile {
        didSet {
            if let data = try? JSONEncoder().encode(profile) { defaults.set(data, forKey: "profile") }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(bags: [SurplusBag] = SurplusBag.samples(around: .now), defaults: UserDefaults = .standard) {
        self.bags = bags
        self.defaults = defaults
        favoriteStores = Set(defaults.stringArray(forKey: "favoriteStores") ?? [])
        alertStores = Set(defaults.stringArray(forKey: "alertStores") ?? [])
        profile = defaults.data(forKey: "profile")
            .flatMap { try? JSONDecoder().decode(CommuteProfile.self, from: $0) } ?? CommuteProfile()

        // Listings change every launch, so rebuild pending alerts from scratch.
        BagAlerts.cancelAll()
        BagAlerts.schedule(bags.filter { alertStores.contains($0.store) })
    }

    func bag(id: SurplusBag.ID) -> SurplusBag? {
        bags.first { $0.id == id }
    }

    /// Reserves bags if they're still available; returns nil if not.
    func reserve(_ id: SurplusBag.ID, quantity: Int, at now: Date = .now) -> Reservation? {
        guard let i = bags.firstIndex(where: { $0.id == id }),
              bags[i].isAvailable(at: now),
              quantity > 0, quantity <= bags[i].bagsLeft
        else { return nil }

        bags[i].bagsLeft -= quantity
        if bags[i].isSoldOut { BagAlerts.cancel([bags[i]]) }
        let code = String((0..<4).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
        let reservation = Reservation(bag: bags[i], quantity: quantity, pickupCode: code, reservedAt: now)
        reservations.append(reservation)
        return reservation
    }

    func reservation(id: Reservation.ID) -> Reservation? {
        reservations.first { $0.id == id }
    }

    /// Confirms pickup at the counter; only allowed during the pickup window.
    func markCollected(_ id: Reservation.ID, at now: Date = .now) {
        guard let i = reservations.firstIndex(where: { $0.id == id }),
              reservations[i].status(at: now) == .readyNow
        else { return }
        reservations[i].collectedAt = now
    }

    func bags(from storeName: String) -> [SurplusBag] {
        bags.filter { $0.store == storeName }
    }

    func isFavorite(_ storeName: String) -> Bool {
        favoriteStores.contains(storeName)
    }

    func hasAlerts(_ storeName: String) -> Bool {
        alertStores.contains(storeName)
    }

    func toggleFavorite(_ storeName: String) {
        if favoriteStores.remove(storeName) != nil {
            alertStores.remove(storeName)
            BagAlerts.cancel(bags(from: storeName))
        } else {
            favoriteStores.insert(storeName)
        }
    }

    /// Turns alerts on or off for a favorite store. Returns false if
    /// notifications aren't allowed, so the caller can explain why.
    func setAlerts(_ enabled: Bool, for storeName: String) async -> Bool {
        guard enabled else {
            alertStores.remove(storeName)
            BagAlerts.cancel(bags(from: storeName))
            return true
        }
        guard await BagAlerts.requestPermission() else { return false }
        favoriteStores.insert(storeName)
        alertStores.insert(storeName)
        BagAlerts.schedule(bags(from: storeName))
        return true
    }

    /// How many bags this order could hold, given what the store has left.
    func maxQuantity(for id: Reservation.ID) -> Int {
        guard let r = reservation(id: id), let bag = bag(id: r.bag.id) else { return 1 }
        return min(Reservation.maxQuantity, r.quantity + bag.bagsLeft)
    }

    /// Changes how many bags are held; the difference goes back to or comes from stock.
    func changeQuantity(_ id: Reservation.ID, to newQuantity: Int, at now: Date = .now) -> Bool {
        guard let r = reservations.firstIndex(where: { $0.id == id }),
              reservations[r].canChange(at: now),
              let b = bags.firstIndex(where: { $0.id == reservations[r].bag.id }),
              newQuantity >= 1, newQuantity <= maxQuantity(for: id)
        else { return false }

        let wasSoldOut = bags[b].isSoldOut
        bags[b].bagsLeft -= newQuantity - reservations[r].quantity
        reservations[r].quantity = newQuantity
        updateAlerts(for: bags[b], wasSoldOut: wasSoldOut)
        return true
    }

    /// Cancels the order and puts its bags back on sale.
    func cancel(_ id: Reservation.ID, reason: CancelReason?, at now: Date = .now) -> Bool {
        guard let r = reservations.firstIndex(where: { $0.id == id }),
              reservations[r].canChange(at: now),
              let b = bags.firstIndex(where: { $0.id == reservations[r].bag.id })
        else { return false }

        let wasSoldOut = bags[b].isSoldOut
        bags[b].bagsLeft += reservations[r].quantity
        reservations[r].cancelledAt = now
        reservations[r].cancelReason = reason
        updateAlerts(for: bags[b], wasSoldOut: wasSoldOut)
        return true
    }

    private func updateAlerts(for bag: SurplusBag, wasSoldOut: Bool) {
        if bag.isSoldOut {
            BagAlerts.cancel([bag])
        } else if wasSoldOut, alertStores.contains(bag.store) {
            BagAlerts.schedule([bag])
        }
    }

    var impact: Impact {
        reservations.filter { $0.collectedAt != nil }.reduce(into: Impact()) { total, r in
            total.bagsRescued += r.quantity
            total.moneySaved += r.savings
        }
    }
}

// MARK: - Sample data

extension SurplusBag {
    /// Demo listings with pickup windows placed around `now`, so the
    /// countdowns always look realistic whenever the app is opened.
    static func samples(around now: Date) -> [SurplusBag] {
        func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }

        return [
            SurplusBag(
                name: "Breakfast Surprise Bag", store: "Sunrise Bagel Co.", category: .breakfast,
                address: "31-10 Queens Blvd, Long Island City", distanceMiles: 0.2, rating: 4.8,
                originalPrice: 15, price: 4.99, pickupStart: at(-15), pickupEnd: at(25), bagsLeft: 2,
                details: "Bagels, cream cheese tubs, and a breakfast sandwich or two from this morning's bake.",
                latitude: 40.7479, longitude: -73.9387
            ),
            SurplusBag(
                name: "Pastry Bag", store: "Corner Crumb Bakery", category: .bakery,
                address: "44-02 Vernon Blvd, Long Island City", distanceMiles: 0.4, rating: 4.9,
                originalPrice: 18, price: 5.99, pickupStart: at(-5), pickupEnd: at(55), bagsLeft: 4,
                details: "A mix of croissants, muffins, and scones that didn't sell at opening.",
                dietary: [.vegetarian],
                latitude: 40.7506, longitude: -73.9474
            ),
            SurplusBag(
                name: "Coffee & Pastry Bag", store: "Daily Grind Coffee", category: .coffee,
                address: "27-15 Jackson Ave, Long Island City", distanceMiles: 0.3, rating: 4.6,
                originalPrice: 12, price: 3.99, pickupStart: at(10), pickupEnd: at(70), bagsLeft: 5,
                details: "A drip coffee with oat milk plus two of today's vegan pastries.",
                dietary: [.vegetarian, .vegan, .dairyFree],
                latitude: 40.7422, longitude: -73.9420
            ),
            SurplusBag(
                name: "Morning Deli Bag", store: "Early Bird Deli", category: .breakfast,
                address: "10-50 Jackson Ave, Long Island City", distanceMiles: 0.7, rating: 4.5,
                originalPrice: 14, price: 4.49, pickupStart: at(-30), pickupEnd: at(90), bagsLeft: 3,
                details: "Egg sandwiches, fruit cups, and yogurt parfaits from the breakfast rush.",
                latitude: 40.7393, longitude: -73.9514
            ),
            SurplusBag(
                name: "Viennoiserie Bag", store: "Petit Matin Pâtisserie", category: .bakery,
                address: "5-25 46th Ave, Long Island City", distanceMiles: 0.9, rating: 4.9,
                originalPrice: 22, price: 6.99, pickupStart: at(-20), pickupEnd: at(40), bagsLeft: 0,
                details: "Pain au chocolat, almond croissants, and brioche.",
                dietary: [.vegetarian],
                latitude: 40.7515, longitude: -73.9576
            ),
            SurplusBag(
                name: "Fresh Produce Bag", store: "Green Basket Market", category: .grocery,
                address: "47-11 Center Blvd, Long Island City", distanceMiles: 1.1, rating: 4.4,
                originalPrice: 20, price: 5.49, pickupStart: at(-10), pickupEnd: at(120), bagsLeft: 6,
                details: "Seasonal fruit, yogurt, and gluten-free granola close to its best-by date.",
                dietary: [.vegetarian, .glutenFree],
                latitude: 40.7355, longitude: -73.9572
            ),
        ]
    }
}
