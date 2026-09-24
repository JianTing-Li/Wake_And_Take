//
//  RateOrderView.swift
//  WakeAndTakeKit
//

import DesignSystem
import Domain
import SwiftUI

struct RateOrderView: View {
    @State private var model: RateOrderModel
    @Environment(\.dismiss) private var dismiss

    init(model: RateOrderModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading: LoadingView()
                case .notFound:
                    EmptyStateView("Order not found", systemImage: "bag", message: "It may have been removed.")
                case .rating: form
                case .submitted: thanks
                }
            }
            .animation(.default, value: model.state)
            .navigationTitle(model.state == .submitted ? "" : "Rate your bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.state != .submitted {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not now") { dismiss() }
                    }
                }
            }
        }
        .tint(.splashTeal)
        .sensoryFeedback(.success, trigger: model.state == .submitted)
        .alert("This order can't be rated anymore", isPresented: $model.failed) {
            Button("OK") { dismiss() }
        } message: {
            Text("Each order can be rated once, within 48 hours of pickup.")
        }
        .task { await model.load() }
    }

    private var form: some View {
        Form {
            Section {
                VStack(spacing: Spacing.s) {
                    Text(model.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    StarRating(rating: $model.overall, size: 36, label: "Overall")
                    Text(model.overallCaption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Details") {
                detailRow("Food quality", $model.quality)
                detailRow("Value for money", $model.value)
                detailRow("Pickup experience", $model.pickup)
            }

            Section("What stood out?") {
                FlowTags(selection: $model.tags)
                    .padding(.vertical, 4)
            }

            Section {
                TextField("Tell the store more (optional)", text: $model.comment, axis: .vertical)
                    .lineLimit(3...6)
            } footer: {
                Text(model.sharingFooter)
            }

            Section {
                Button {
                    Task { await model.submit() }
                } label: {
                    Text("Submit rating")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSubmit)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    private func detailRow(_ title: String, _ rating: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            StarRating(rating: rating, size: 20, label: title)
        }
    }

    private var thanks: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.splashTeal)
                .accessibilityHidden(true)
            Text("Thanks for your rating!").font(.title2.weight(.bold))
            if let thanks = model.thanksText {
                Text(thanks)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Spacing.xxl)
    }
}
