//
//  ManageOrderView.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import SwiftUI

struct ManageOrderView: View {
    @State private var model: ManageOrderModel
    @Environment(\.dismiss) private var dismiss

    init(model: ManageOrderModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading: LoadingView()
            case .notFound: EmptyStateView("Order not found", systemImage: "bag", message: "It may have been removed.")
            case .loaded: form
            }
        }
        .navigationTitle("Manage order")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: model.finished)
        .onChange(of: model.finished) { if model.finished { dismiss() } }
        .confirmationDialog("Cancel this order?", isPresented: $model.confirmingCancel, titleVisibility: .visible) {
            Button("Cancel order", role: .destructive) { Task { await model.cancel() } }
            Button("Keep order", role: .cancel) {}
        } message: {
            Text(model.cancelMessage)
        }
        .alert("This order can't be changed anymore", isPresented: $model.failed) {
            Button("OK") { dismiss() }
        } message: {
            Text("The change deadline passed or the store ran out of bags.")
        }
        .task { await model.run() }
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent(model.restaurantName, value: model.orderText)
                LabeledContent("Pickup", value: model.pickupText)
            }

            Section { deadlineNotice }

            if model.isOpen {
                Section {
                    Stepper(value: $model.quantity, in: 1...model.maxQuantity) {
                        LabeledContent("Bags", value: "\(model.quantity)")
                    }
                    LabeledContent("New total") {
                        Text(model.newTotal.usd)
                            .fontWeight(.semibold)
                            .foregroundStyle(model.canSave ? Color.splashTeal : .secondary)
                    }
                    Button("Save changes") { Task { await model.saveQuantity() } }
                        .disabled(!model.canSave)
                } header: {
                    Text("Change quantity")
                } footer: {
                    Text(model.quantityFooter)
                }

                Section {
                    Picker("Reason (optional)", selection: $model.reason) {
                        Text("Choose…").tag(CancelReason?.none)
                        ForEach(CancelReason.allCases) { Text($0.label).tag(CancelReason?.some($0)) }
                    }
                    Button("Cancel order", role: .destructive) { model.confirmingCancel = true }
                } header: {
                    Text("Cancel order")
                } footer: {
                    Text(
                        "Cancelling puts your bags back on sale so the food still gets rescued. "
                            + "Your reason helps the store plan better.")
                }
            }
        }
    }

    private var deadlineNotice: some View {
        let notice = model.deadlineNotice
        return Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).fontWeight(.semibold)
                Text(notice.detail).font(.footnote).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: model.isOpen ? "clock.badge.checkmark" : "lock.fill")
                .foregroundStyle(model.isOpen ? Color.splashTeal : .secondary)
        }
    }
}
