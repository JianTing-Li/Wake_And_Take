//
//  PickupView.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import SwiftUI

struct PickupView<RateSheet: View>: View {
    @State private var model: PickupModel
    let rateSheet: (RateRequest) -> RateSheet

    init(model: PickupModel, @ViewBuilder rateSheet: @escaping (RateRequest) -> RateSheet) {
        _model = State(initialValue: model)
        self.rateSheet = rateSheet
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading: LoadingView()
            case .notFound: EmptyStateView("Order not found", systemImage: "bag", message: "It may have been removed.")
            case .failed(let message):
                EmptyStateView(
                    "Something went wrong", systemImage: "exclamationmark.triangle", message: message,
                    actionTitle: "Try again"
                ) { Task { await model.load() } }
            case .loaded: content
            }
        }
        .navigationTitle(model.restaurantName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $model.rateRequest, content: rateSheet)
        .alert("Pickup couldn't be confirmed", isPresented: $model.collectFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can confirm pickup only while the pickup window is open.")
        }
        .task { await model.run() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                if let header = model.header { StatusHeader(header: header) }

                if model.isActive {
                    PickupCodeCard(code: model.code)
                    PickupSteps(
                        restaurantName: model.restaurantName, addressLine: model.addressLine,
                        instructions: model.pickupInstructions, directionsURL: model.directionsURL)
                    if model.canManage, let id = model.reservation?.id {
                        NavigationLink(value: OrdersRoute.manageOrder(reservationID: id)) {
                            Label("Change or cancel order", systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.m)
                                .background(
                                    Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: Radius.panel))
                        }
                    } else if let text = model.changesClosedText {
                        Text(text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if model.status == .collected {
                    RatingCard(
                        restaurantName: model.restaurantName, review: model.review, canReview: model.canReview
                    ) { model.rate(stars: $0) }
                    if let impact = model.impactText {
                        VStack(spacing: 6) {
                            Text("This order's impact").font(.headline)
                            Text(impact).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.l)
                        .background(
                            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card))
                    }
                }

                summary
            }
            .padding(Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if model.status == .readyNow {
            SwipeToConfirm(title: "Swipe to confirm pickup") { Task { await model.collect() } }
                .padding(Spacing.l)
                .background(.bar)
        } else if let text = model.confirmFromText {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(Spacing.xl)
                .background(.bar)
        }
    }

    private var summary: some View {
        VStack(spacing: Spacing.s) {
            ForEach(model.summary, id: \.label) { row in
                HStack(alignment: .top) {
                    Text(row.label).foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value).fontWeight(.semibold).multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Spacing.l)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

private struct StatusHeader: View {
    let header: PickupModel.Header

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: header.symbol)
                .font(.system(size: 52))
                .foregroundStyle(header.tone.headerColor)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
            Text(header.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
            Text(header.subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
}

extension PickupStatusPill.Tone {
    fileprivate var headerColor: Color {
        switch self {
        case .readyNow: .splashTeal
        case .upcoming: .orange
        case .collected: .green
        case .inactive: .secondary
        }
    }
}
