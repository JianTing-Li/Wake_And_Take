//
//  DiscoverView.swift
//  Wake_And_Take
//
//  User Journey 1: a customer finds affordable surplus food nearby
//  and reserves it before the pickup window ends.
//

import SwiftUI

struct DiscoverView: View {
    let store: BagStore
    @State private var category: FoodCategory?
    @State private var sort: SortOrder = .endingSoon

    enum SortOrder: String, CaseIterable, Identifiable {
        case endingSoon = "Ending soon"
        case nearest = "Nearest"
        case cheapest = "Cheapest"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = context.date
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(now: now)
                        categoryChips
                        Picker("Sort", selection: $sort) {
                            ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        let bags = visibleBags(at: now)
                        if bags.isEmpty {
                            ContentUnavailableView(
                                "No bags right now",
                                systemImage: "bag",
                                description: Text("Check back soon. Stores add bags throughout the morning.")
                            )
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(bags) { bag in
                                    NavigationLink(value: bag.id) {
                                        BagCard(bag: bag, now: now,
                                                isFavorite: store.isFavorite(bag.store),
                                                fitsCommute: store.profile.fitsCommute(bag, on: now)) {
                                            store.toggleFavorite(bag.store)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Discover")
            .toolbar {
                NavigationLink {
                    MapBrowseView(store: store)
                } label: {
                    Label("Map", systemImage: "map")
                }
            }
            .navigationDestination(for: SurplusBag.ID.self) { id in
                BagDetailView(store: store, bagID: id)
            }
        }
        .tint(.splashTeal)
    }

    private func header(now: Date) -> some View {
        let profile = store.profile
        let available = store.bags.filter { $0.isAvailable(at: now) && profile.matches($0) }.count
        let hiddenByPrefs = store.bags.filter { $0.isAvailable(at: now) && !profile.matches($0) }.count
        let distance = profile.maxDistanceMiles.formatted(.number.precision(.fractionLength(0...2)))

        return VStack(alignment: .leading, spacing: 4) {
            if !profile.name.isEmpty {
                Text("Good morning, \(profile.name)")
                    .font(.title3.weight(.semibold))
            }
            Label("Near you · \(profile.homeArea)", systemImage: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.splashTeal)
            Text("\(available) bags to rescue within \(distance) mi")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if hiddenByPrefs > 0 {
                Text("\(hiddenByPrefs) more hidden by your distance or dietary preferences")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", symbol: "square.grid.2x2.fill", selected: category == nil) { category = nil }
                ForEach(FoodCategory.allCases) { c in
                    chip(c.rawValue, symbol: c.symbol, selected: category == c) { category = c }
                }
            }
        }
    }

    private func chip(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.splashTeal : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Filtered and sorted, with bags you can't reserve pushed to the bottom.
    private func visibleBags(at now: Date) -> [SurplusBag] {
        store.bags
            .filter { category == nil || $0.category == category }
            .filter { store.profile.matches($0) }
            .sorted { a, b in
                let aOpen = a.isAvailable(at: now), bOpen = b.isAvailable(at: now)
                if aOpen != bOpen { return aOpen }
                switch sort {
                case .endingSoon: return a.pickupEnd < b.pickupEnd
                case .nearest: return a.distanceMiles < b.distanceMiles
                case .cheapest: return a.price < b.price
                }
            }
    }
}

// MARK: - Card

struct BagCard: View {
    let bag: SurplusBag
    let now: Date
    var isFavorite = false
    var fitsCommute = false
    var onToggleFavorite: (() -> Void)?

    var body: some View {
        let available = bag.isAvailable(at: now)

        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [bag.category.tint, bag.category.tint.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 100)
                .overlay {
                    Image(systemName: bag.category.symbol)
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.9))
                }

                HStack(alignment: .top) {
                    StatusBadge(bag: bag, now: now)
                    if available {
                        Text("-\(bag.savingsPercent)%")
                            .font(.caption.weight(.heavy))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.yolk, in: Capsule())
                            .foregroundStyle(.black)
                    }
                    Spacer()
                    if let onToggleFavorite {
                        FavoriteButton(isFavorite: isFavorite, action: onToggleFavorite)
                    }
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(bag.store).font(.headline)
                    Spacer()
                    Label(String(format: "%.1f", bag.rating), systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(bag.name).font(.subheadline).foregroundStyle(.secondary)
                if fitsCommute && available {
                    Label("Fits your commute", systemImage: "tram.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.splashTeal)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.splashTeal.opacity(0.12), in: Capsule())
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Pick up \(bag.pickupWindow)", systemImage: "clock")
                        Label(String(format: "%.1f mi away", bag.distanceMiles), systemImage: "figure.walk")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(bag.originalPrice, format: .currency(code: "USD"))
                            .font(.caption)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text(bag.price, format: .currency(code: "USD"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.splashTeal)
                    }
                }
                .padding(.top, 2)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .opacity(available ? 1 : 0.55)
        .accessibilityElement(children: .combine)
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.body.weight(.semibold))
                .foregroundStyle(isFavorite ? .red : .white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.35), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

struct StatusBadge: View {
    let bag: SurplusBag
    let now: Date

    var body: some View {
        let urgent = bag.endsSoon(at: now)
        let text = bag.isAvailable(at: now) && !urgent && now >= bag.pickupStart
            ? "\(bag.bagsLeft) left"
            : bag.urgency(at: now)

        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(urgent ? Color.red : Color.black.opacity(0.55), in: Capsule())
            .foregroundStyle(.white)
    }
}

#Preview {
    DiscoverView(store: BagStore())
}
