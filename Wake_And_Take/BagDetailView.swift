//
//  BagDetailView.swift
//  Wake_And_Take
//

import SwiftUI

struct BagDetailView: View {
    let store: BagStore
    let bagID: SurplusBag.ID

    @State private var quantity = 1
    @State private var confirmation: Reservation?
    @State private var showUnavailableAlert = false

    var body: some View {
        if let bag = store.bag(id: bagID) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                content(bag, now: context.date)
            }
            .navigationTitle(bag.store)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    store.toggleFavorite(bag.store)
                } label: {
                    Image(systemName: store.isFavorite(bag.store) ? "heart.fill" : "heart")
                        .foregroundStyle(store.isFavorite(bag.store) ? .red : .primary)
                }
                .accessibilityLabel(store.isFavorite(bag.store) ? "Remove from favorites" : "Add to favorites")
            }
            .sheet(item: $confirmation) { ReservationConfirmationView(reservation: $0) }
            .alert("This bag is no longer available", isPresented: $showUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It sold out or the pickup window ended. Try another bag nearby.")
            }
        } else {
            ContentUnavailableView("Bag not found", systemImage: "bag")
        }
    }

    private func content(_ bag: SurplusBag, now: Date) -> some View {
        let available = bag.isAvailable(at: now)
        let maxQuantity = max(1, min(bag.bagsLeft, 3))

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LinearGradient(
                    colors: [bag.category.tint, bag.category.tint.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 180)
                .overlay {
                    Image(systemName: bag.category.symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .overlay(alignment: .bottomLeading) {
                    StatusBadge(bag: bag, now: now).padding(12)
                }

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bag.name).font(.title2.weight(.bold))
                        Label(String(format: "%.1f (%d ratings) · %@", bag.rating, bag.reviewCount, bag.category.rawValue), systemImage: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        InfoRow(symbol: "clock", title: "Pick up today \(bag.pickupWindow)", subtitle: bag.urgency(at: now))
                        Divider()
                        InfoRow(symbol: "mappin.and.ellipse", title: bag.address,
                                subtitle: String(format: "%.1f mi away", bag.distanceMiles))
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What you could get").font(.headline)
                        Text(bag.details).foregroundStyle(.secondary)
                        if !bag.dietary.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(DietaryTag.allCases.filter(bag.dietary.contains)) { tag in
                                    Label(tag.label, systemImage: tag.symbol)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.splashTeal.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.splashTeal)
                                }
                            }
                        }
                        Text("It's a surprise! Contents depend on what's left at the end of the morning.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Price").font(.headline)
                            Text("You save \(bag.savingsPercent)%").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(bag.originalPrice, format: .currency(code: "USD"))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text(bag.price, format: .currency(code: "USD"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.splashTeal)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if available {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...maxQuantity)
                }
                Button {
                    reserve(bag)
                } label: {
                    Group {
                        if available {
                            Text("Reserve · \(Double(quantity) * bag.price, format: .currency(code: "USD"))")
                        } else {
                            Text(bag.urgency(at: now))
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.splashTeal)
                .disabled(!available)
            }
            .padding(16)
            .background(.bar)
            .onChange(of: maxQuantity) { quantity = min(quantity, maxQuantity) }
        }
    }

    private func reserve(_ bag: SurplusBag) {
        if let reservation = store.reserve(bag.id, quantity: quantity) {
            quantity = 1
            confirmation = reservation
        } else {
            showUnavailableAlert = true
        }
    }
}

private struct InfoRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.splashTeal)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Confirmation

struct ReservationConfirmationView: View {
    let reservation: Reservation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.splashTeal)
                .padding(.top, 32)

            VStack(spacing: 6) {
                Text("You're all set!").font(.title.weight(.bold))
                Text("Show this code at \(reservation.bag.store) when you pick up")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(reservation.pickupCode)
                .font(.system(size: 44, weight: .heavy, design: .monospaced))
                .tracking(8)
                .padding(.vertical, 12).padding(.horizontal, 24)
                .background(Color.yolk.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Pickup code \(reservation.pickupCode.map(String.init).joined(separator: " "))")

            Text("Free changes and cancellation until \(reservation.changeDeadline.formatted(date: .omitted, time: .shortened)). Find this order anytime in the Orders tab.")
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                row("Pickup", "Today \(reservation.bag.pickupWindow)")
                row("Where", reservation.bag.address)
                row("Bags", "\(reservation.quantity) × \(reservation.bag.name)")
                row("Total", reservation.total.formatted(.currency(code: "USD")))
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.splashTeal)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    let store = BagStore()
    return NavigationStack {
        BagDetailView(store: store, bagID: store.bags[0].id)
    }
}
