//
//  OrdersView.swift
//  Wake_And_Take
//
//  User Journey 2: a customer picks up the order they reserved —
//  knows when and where to go, shows their code, and confirms pickup.
//

import DesignSystem
import SwiftUI

struct OrdersView: View {
    let store: BagStore
    var onFindFood: () -> Void = {}

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = context.date
                let active = store.reservations
                    .filter { $0.isActive(at: now) }
                    .sorted { $0.bag.pickupEnd < $1.bag.pickupEnd }
                let past = store.reservations
                    .filter { !$0.isActive(at: now) }
                    .reversed()

                List {
                    Section {
                        ImpactCard(impact: store.impact)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    if store.reservations.isEmpty {
                        ContentUnavailableView {
                            Label("No orders yet", systemImage: "bag")
                        } description: {
                            Text("Reserve a surprise bag and it will show up here with your pickup code.")
                        } actions: {
                            Button("Find food nearby", action: onFindFood)
                                .buttonStyle(.borderedProminent)
                        }
                        .listRowBackground(Color.clear)
                    }

                    if !active.isEmpty {
                        Section("Upcoming pickups") {
                            ForEach(active) { r in
                                NavigationLink(value: r.id) { OrderRow(reservation: r, now: now) }
                            }
                        }
                    }

                    if !past.isEmpty {
                        Section("Past orders") {
                            ForEach(past) { r in
                                NavigationLink(value: r.id) { OrderRow(reservation: r, now: now) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Orders")
            .navigationDestination(for: Reservation.ID.self) { id in
                PickupView(store: store, reservationID: id)
            }
            .navigationDestination(for: ManageOrderRoute.self) { route in
                ManageOrderView(store: store, reservationID: route.id)
            }
        }
        .tint(.splashTeal)
    }
}

// MARK: - Impact

struct ImpactCard: View {
    let impact: Impact

    var body: some View {
        HStack(spacing: 0) {
            stat("\(impact.bagsRescued)", "bags rescued", symbol: "bag.fill")
            Divider().frame(height: 44).overlay(Color.white.opacity(0.3))
            stat(impact.moneySaved.formatted(.currency(code: "USD")), "saved", symbol: "dollarsign.circle.fill")
            Divider().frame(height: 44).overlay(Color.white.opacity(0.3))
            stat(String(format: "%.1f kg", impact.co2eAvoided), "CO₂e avoided", symbol: "leaf.fill")
        }
        .padding(.vertical, 16)
        .foregroundStyle(.white)
        .background(Color.splashTeal, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(Color.yolk)
            Text(value).font(.title3.weight(.bold)).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption).opacity(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

struct OrderRow: View {
    let reservation: Reservation
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reservation.bag.category.symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(reservation.bag.category.tint, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(reservation.bag.store).font(.headline)
                Text("\(reservation.quantity) × \(reservation.bag.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                PickupStatusPill(reservation: reservation, now: now)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PickupStatusPill: View {
    let reservation: Reservation
    let now: Date

    var body: some View {
        let (text, color): (String, Color) = switch reservation.status(at: now) {
        case .readyNow: ("Ready now · \(reservation.bag.pickupCountdown(at: now))", .splashTeal)
        case .upcoming: (reservation.bag.pickupCountdown(at: now), .orange)
        case .collected: ("Picked up", .green)
        case .missed: ("Missed pickup", .secondary)
        case .cancelled: ("Cancelled", .secondary)
        }
        HStack(spacing: 6) {
            Text(text).foregroundStyle(color)
            if let review = reservation.review {
                StarsDisplay(rating: review.overall, size: 10)
            } else if reservation.canReview(at: now) {
                Text("· Rate your bag").foregroundStyle(.orange)
            }
        }
        .font(.caption.weight(.semibold))
    }
}

// MARK: - Pickup

struct PickupView: View {
    let store: BagStore
    let reservationID: Reservation.ID

    private struct RateRequest: Identifiable {
        let id = UUID()
        let stars: Int
    }
    @State private var rateRequest: RateRequest?

    var body: some View {
        if let reservation = store.reservation(id: reservationID) {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                content(reservation, now: context.date)
            }
            .navigationTitle(reservation.bag.store)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $rateRequest) { request in
                RateOrderView(store: store, reservationID: reservationID, initialStars: request.stars)
            }
        } else {
            ContentUnavailableView("Order not found", systemImage: "bag")
        }
    }

    private func content(_ r: Reservation, now: Date) -> some View {
        let status = r.status(at: now)

        return ScrollView {
            VStack(spacing: 20) {
                statusHeader(r, status: status, now: now)

                if status == .upcoming || status == .readyNow {
                    VStack(spacing: 8) {
                        Text("Pickup code").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Text(r.pickupCode)
                            .font(.system(size: 48, weight: .heavy, design: .monospaced))
                            .tracking(10)
                            .accessibilityLabel("Pickup code \(r.pickupCode.map(String.init).joined(separator: " "))")
                        Text("Show this to staff at the counter")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.yolk.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))

                    steps(r)

                    if r.canChange(at: now) {
                        NavigationLink(value: ManageOrderRoute(id: r.id)) {
                            Label("Change or cancel order", systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        Text("Changes closed at \(r.changeDeadline.formatted(date: .omitted, time: .shortened)). The store is getting your bag ready.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if status == .collected {
                    ratingCard(r, now: now)

                    VStack(spacing: 6) {
                        Text("This order's impact").font(.headline)
                        Text("You saved \(r.savings.formatted(.currency(code: "USD"))) and about \(String(format: "%.1f", Double(r.quantity) * Impact.co2ePerBag)) kg of CO₂e.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }

                summary(r)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            switch status {
            case .readyNow:
                SwipeToConfirm(title: "Swipe to confirm pickup") {
                    store.markCollected(r.id)
                }
                .padding(16)
                .background(.bar)
            case .upcoming:
                Text("You can confirm pickup from \(r.bag.pickupStart.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(.bar)
            case .collected, .missed, .cancelled:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func ratingCard(_ r: Reservation, now: Date) -> some View {
        if let review = r.review {
            VStack(spacing: 8) {
                Text("You rated this bag").font(.headline)
                StarsDisplay(rating: review.overall, size: 22)
                if !review.tags.isEmpty {
                    Text(ReviewTag.allCases.filter(review.tags.contains).map(\.rawValue).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        } else if r.canReview(at: now) {
            VStack(spacing: 10) {
                Text("How was your bag?").font(.headline)
                StarRating(
                    rating: Binding(get: { 0 }, set: { rateRequest = RateRequest(stars: $0) }),
                    size: 34,
                    label: "Rate your bag"
                )
                Text("Tap a star to rate \(r.bag.store)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.yolk.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func statusHeader(_ r: Reservation, status: Reservation.Status, now: Date) -> some View {
        let time = { (d: Date) in d.formatted(date: .omitted, time: .shortened) }
        let (symbol, color, title, subtitle): (String, Color, String, String) = switch status {
        case .readyNow:
            ("bag.fill", .splashTeal, "Ready for pickup", "\(r.bag.pickupCountdown(at: now)) · until \(time(r.bag.pickupEnd))")
        case .upcoming:
            ("clock.fill", .orange, "Pickup opens at \(time(r.bag.pickupStart))", "Your bag is held until \(time(r.bag.pickupEnd))")
        case .collected:
            ("checkmark.circle.fill", .green, "Enjoy your breakfast!", "Picked up at \(time(r.collectedAt ?? now))")
        case .missed:
            ("xmark.circle.fill", .secondary, "Pickup window ended", "This order wasn't collected before \(time(r.bag.pickupEnd)).")
        case .cancelled:
            ("xmark.circle.fill", .secondary, "Order cancelled",
             "Cancelled at \(time(r.cancelledAt ?? now)). You won't be charged, and your bag is back on sale for someone else.")
        }

        return VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 52))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
            Text(title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func steps(_ r: Reservation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            step(1, "Head to \(r.bag.store)", detail: "\(r.bag.address) · \(String(format: "%.1f mi", r.bag.distanceMiles))") {
                if let url = directionsURL(for: r.bag.address) {
                    Link(destination: url) {
                        Label("Get directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            step(2, "Show your pickup code", detail: "Staff will hand you your surprise bag.")
            step(3, "Confirm pickup together", detail: "Swipe below while you're at the counter.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func step(_ n: Int, _ title: String, detail: String, @ViewBuilder extra: () -> some View = { EmptyView() }) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.splashTeal, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
                extra()
            }
        }
    }

    private func summary(_ r: Reservation) -> some View {
        VStack(spacing: 10) {
            summaryRow("Order", "\(r.quantity) × \(r.bag.name)")
            summaryRow("Pickup window", "Today \(r.bag.pickupWindow)")
            summaryRow("Total", r.total.formatted(.currency(code: "USD")))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func directionsURL(for address: String) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "daddr", value: address)]
        return components?.url
    }
}

// MARK: - Swipe to confirm

/// A slide-to-confirm control so pickup isn't confirmed by an accidental tap.
struct SwipeToConfirm: View {
    let title: String
    let action: () -> Void

    @State private var offset: CGFloat = 0
    @State private var confirmed = false
    private let knob: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let maxOffset = max(geo.size.width - knob - 8, 1)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.splashTeal.opacity(0.15))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.splashTeal)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - offset / maxOffset)

                Circle()
                    .fill(Color.splashTeal)
                    .frame(width: knob, height: knob)
                    .overlay {
                        Image(systemName: confirmed ? "checkmark" : "chevron.right.2")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4 + offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !confirmed else { return }
                                offset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                guard !confirmed else { return }
                                if offset > maxOffset * 0.85 {
                                    withAnimation(.spring(duration: 0.3)) { offset = maxOffset }
                                    confirm()
                                } else {
                                    withAnimation(.spring(duration: 0.3)) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: knob + 8)
        .sensoryFeedback(.success, trigger: confirmed)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirm() }
    }

    private func confirm() {
        guard !confirmed else { return }
        confirmed = true
        action()
    }
}

#Preview {
    let store = BagStore()
    _ = store.reserve(store.bags[0].id, quantity: 2)
    _ = store.reserve(store.bags[2].id, quantity: 1)
    return OrdersView(store: store)
}
