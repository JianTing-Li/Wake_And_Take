//
//  ManageOrderView.swift
//  Wake_And_Take
//
//  User Journey 5: a customer's plans change, so they change how many
//  bags they're picking up or cancel the order before the deadline.
//

import DesignSystem
import SwiftUI

/// Navigation value for this page (distinct from the pickup page's plain ID).
struct ManageOrderRoute: Hashable {
    let id: Reservation.ID
}

struct ManageOrderView: View {
    let store: BagStore
    let reservationID: Reservation.ID

    @State private var quantity = 1
    @State private var reason: CancelReason?
    @State private var confirmingCancel = false
    @State private var failed = false
    @State private var finished = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let r = store.reservation(id: reservationID) {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                content(r, now: context.date)
            }
            .navigationTitle("Manage order")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { quantity = r.quantity }
            .sensoryFeedback(.success, trigger: finished)
            .confirmationDialog("Cancel this order?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Cancel order", role: .destructive) { cancel() }
                Button("Keep order", role: .cancel) {}
            } message: {
                Text("Your \(r.quantity == 1 ? "bag goes" : "bags go") back on sale for other customers. You won't be charged.")
            }
            .alert("This order can't be changed anymore", isPresented: $failed) {
                Button("OK") { dismiss() }
            } message: {
                Text("The change deadline passed or the store ran out of bags.")
            }
        } else {
            ContentUnavailableView("Order not found", systemImage: "bag")
        }
    }

    private func content(_ r: Reservation, now: Date) -> some View {
        let open = r.canChange(at: now)
        let maxQuantity = store.maxQuantity(for: r.id)

        return Form {
            Section {
                LabeledContent(r.bag.store, value: "\(r.quantity) × \(r.bag.name)")
                LabeledContent("Pickup", value: "Today \(r.bag.pickupWindow)")
            }

            Section {
                deadlineNotice(r, open: open, now: now)
            }

            if open {
                Section {
                    Stepper(value: $quantity, in: 1...maxQuantity) {
                        LabeledContent("Bags", value: "\(quantity)")
                    }
                    LabeledContent("New total") {
                        Text(Double(quantity) * r.bag.price, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                            .foregroundStyle(quantity == r.quantity ? .secondary : Color.splashTeal)
                    }
                    Button("Save changes") { saveQuantity() }
                        .disabled(quantity == r.quantity)
                } header: {
                    Text("Change quantity")
                } footer: {
                    Text(maxQuantity > r.quantity
                         ? "You can hold up to \(maxQuantity) bags. \(r.bag.store) has \(maxQuantity - r.quantity) more available."
                         : "\(r.bag.store) has no more bags available, but you can reduce your order.")
                }

                Section {
                    Picker("Reason (optional)", selection: $reason) {
                        Text("Choose…").tag(CancelReason?.none)
                        ForEach(CancelReason.allCases) { Text($0.rawValue).tag(CancelReason?.some($0)) }
                    }
                    Button("Cancel order", role: .destructive) { confirmingCancel = true }
                } header: {
                    Text("Cancel order")
                } footer: {
                    Text("Cancelling puts your bags back on sale so the food still gets rescued. Your reason helps the store plan better.")
                }
            }
        }
    }

    @ViewBuilder
    private func deadlineNotice(_ r: Reservation, open: Bool, now: Date) -> some View {
        let deadline = r.changeDeadline.formatted(date: .omitted, time: .shortened)
        if open {
            let minutes = max(1, Int(r.changeDeadline.timeIntervalSince(now) / 60))
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free changes until \(deadline)").fontWeight(.semibold)
                    Text(minutes < 60 ? "\(minutes) min left" : "10 minutes before pickup ends")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "clock.badge.checkmark").foregroundStyle(Color.splashTeal)
            }
        } else {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Changes closed at \(deadline)").fontWeight(.semibold)
                    Text("The store is getting your bag ready.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
            }
        }
    }

    private func saveQuantity() {
        if store.changeQuantity(reservationID, to: quantity) {
            finished = true
            dismiss()
        } else {
            failed = true
        }
    }

    private func cancel() {
        if store.cancel(reservationID, reason: reason) {
            finished = true
            dismiss()
        } else {
            failed = true
        }
    }
}

#Preview {
    let store = BagStore(defaults: UserDefaults(suiteName: "preview")!)
    let r = store.reserve(store.bags[1].id, quantity: 2)!
    return NavigationStack {
        ManageOrderView(store: store, reservationID: r.id)
    }
    .tint(.splashTeal)
}
