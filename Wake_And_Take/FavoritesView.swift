//
//  FavoritesView.swift
//  Wake_And_Take
//
//  User Journey 3: a customer saves favorite stores and gets alerted
//  when they have bags, so they never miss a deal on their commute.
//

import SwiftUI

struct FavoritesView: View {
    let store: BagStore
    var onBrowse: () -> Void = {}

    @State private var notificationsBlocked = false
    @State private var previewSent = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = context.date
                List {
                    if store.favoriteStores.isEmpty {
                        ContentUnavailableView {
                            Label("No favorites yet", systemImage: "heart")
                        } description: {
                            Text("Tap the heart on any store to save it here. Turn on alerts to hear when it has bags.")
                        } actions: {
                            Button("Browse stores", action: onBrowse)
                                .buttonStyle(.borderedProminent)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(sortedFavorites(at: now), id: \.self) { name in
                                row(for: name, now: now)
                            }
                            .onDelete { offsets in
                                let names = sortedFavorites(at: now)
                                offsets.map { names[$0] }.forEach(store.toggleFavorite)
                            }
                        } header: {
                            Text("Your stores")
                        } footer: {
                            Text("Tap the bell to get a notification when a store's bags open for pickup.")
                        }

                        if let sample = alertPreviewBag {
                            Section {
                                Button {
                                    Task {
                                        if await BagAlerts.requestPermission() {
                                            BagAlerts.sendPreview(for: sample)
                                            previewSent = true
                                        } else {
                                            notificationsBlocked = true
                                        }
                                    }
                                } label: {
                                    Label(previewSent ? "Alert on its way…" : "Preview an alert",
                                          systemImage: "bell.badge")
                                }
                            } footer: {
                                Text("Sends a sample alert in 5 seconds so you can see what it looks like.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: SurplusBag.ID.self) { id in
                BagDetailView(store: store, bagID: id)
            }
            .alert("Notifications are off", isPresented: $notificationsBlocked) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Allow notifications for Wake & Take in Settings to get alerts from your favorite stores.")
            }
            .onChange(of: previewSent) {
                guard previewSent else { return }
                Task {
                    try? await Task.sleep(for: .seconds(6))
                    previewSent = false
                }
            }
        }
        .tint(.splashTeal)
    }

    @ViewBuilder
    private func row(for name: String, now: Date) -> some View {
        let next = nextBag(from: name, at: now)
        let label = FavoriteStoreRow(
            name: name,
            category: store.bags(from: name).first?.category,
            status: status(for: name, next: next, now: now),
            alertsOn: store.hasAlerts(name)
        ) {
            Task {
                let turnOn = !store.hasAlerts(name)
                if await !store.setAlerts(turnOn, for: name) {
                    notificationsBlocked = true
                }
            }
        }

        if let next {
            NavigationLink(value: next.id) { label }
        } else {
            // Leave room where the chevron would be so bells line up.
            label.padding(.trailing, 19)
        }
    }

    /// Stores with bags available now first, then upcoming, then none.
    private func sortedFavorites(at now: Date) -> [String] {
        func rank(_ name: String) -> Int {
            guard let bag = nextBag(from: name, at: now) else { return 2 }
            return now >= bag.pickupStart ? 0 : 1
        }
        return store.favoriteStores.sorted { (rank($0), $0) < (rank($1), $1) }
    }

    /// The store's bag that's open now or opens soonest.
    private func nextBag(from name: String, at now: Date) -> SurplusBag? {
        store.bags(from: name)
            .filter { $0.isAvailable(at: now) }
            .min { $0.pickupStart < $1.pickupStart }
    }

    private func status(for name: String, next: SurplusBag?, now: Date) -> FavoriteStoreRow.Status {
        guard let next else { return .none }
        if now >= next.pickupStart {
            return .availableNow("\(next.bagsLeft) left · \(next.pickupCountdown(at: now))")
        }
        return .upcoming(next.pickupCountdown(at: now))
    }

    private var alertPreviewBag: SurplusBag? {
        store.bags.first { store.isFavorite($0.store) } ?? store.bags.first
    }
}

struct FavoriteStoreRow: View {
    enum Status {
        case availableNow(String), upcoming(String), none
    }

    let name: String
    let category: FoodCategory?
    let status: Status
    let alertsOn: Bool
    let onToggleAlerts: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category?.symbol ?? "storefront.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(category?.tint ?? .gray, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.headline)
                statusText
            }

            Spacer(minLength: 8)

            Button(action: onToggleAlerts) {
                Image(systemName: alertsOn ? "bell.fill" : "bell.slash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(alertsOn ? Color.splashTeal : .secondary)
                    .frame(width: 40, height: 40)
                    .background(alertsOn ? Color.splashTeal.opacity(0.15) : Color(.tertiarySystemFill), in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .sensoryFeedback(.selection, trigger: alertsOn)
            .accessibilityLabel(alertsOn ? "Turn off alerts for \(name)" : "Turn on alerts for \(name)")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .availableNow(let text):
            Label(text, systemImage: "bag.fill").foregroundStyle(Color.splashTeal)
                .font(.caption.weight(.semibold))
        case .upcoming(let text):
            Label(text, systemImage: "clock").foregroundStyle(.orange)
                .font(.caption.weight(.semibold))
        case .none:
            Text("No bags left today").foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    let store = BagStore(defaults: UserDefaults(suiteName: "preview")!)
    if store.favoriteStores.isEmpty {
        ["Daily Grind Coffee", "Sunrise Bagel Co.", "Petit Matin Pâtisserie"].forEach(store.toggleFavorite)
    }
    return FavoritesView(store: store)
}
