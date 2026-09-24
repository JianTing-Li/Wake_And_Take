//
//  OfferDetailView.swift
//  WakeAndTakeKit
//

import DesignSystem
import Domain
import MapKit
import SwiftUI

public struct OfferDetailView: View {
    @State private var model: OfferDetailModel

    public init(model: OfferDetailModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        @Bindable var reserve = model.reserve

        Group {
            switch model.state {
            case .loading:
                LoadingView()
            case .notFound:
                EmptyStateView("Bag not found", systemImage: "bag", message: "It may have been removed.")
            case .failed(let message):
                EmptyStateView(
                    "Something went wrong", systemImage: "exclamationmark.triangle", message: message,
                    actionTitle: "Try again"
                ) { Task { await model.load() } }
            case .loaded:
                content.safeAreaInset(edge: .bottom) { reserveBar(reserve) }
            }
        }
        .navigationTitle(model.restaurantName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.showsFavoriteButton, model.state == .loaded {
                Button {
                    Task { await model.toggleFavorite() }
                } label: {
                    Image(systemName: model.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(model.isFavorite ? .red : .primary)
                }
                .accessibilityLabel(model.isFavorite ? "Remove from favorites" : "Add to favorites")
            }
        }
        .sheet(item: $reserve.confirmation) { confirmation in
            ReservationConfirmationView(confirmation: confirmation) { model.viewOrder(confirmation) }
        }
        .alert(
            reserve.alert?.title ?? "",
            isPresented: Binding(get: { reserve.alert != nil }, set: { if !$0 { reserve.alert = nil } }),
            presenting: reserve.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
        .task { await model.run() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                CategoryGradient(category: model.category, symbolSize: 64)
                    .frame(height: 180)
                    .overlay(alignment: .bottomLeading) {
                        StatusBadge(text: model.badgeText, isUrgent: model.isUrgent).padding(Spacing.m)
                    }

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.bagName).font(.title2.weight(.bold))
                        Label(model.subtitle, systemImage: model.flags.reviews ? "star.fill" : model.category.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: Spacing.m) {
                        InfoRow(symbol: "clock", title: model.pickupText, subtitle: model.urgencyText)
                        Divider()
                        InfoRow(
                            symbol: "mappin.and.ellipse", title: model.addressTitle, subtitle: model.addressSubtitle)
                        if let coordinate = model.coordinate {
                            LocationPreview(name: model.restaurantName, coordinate: coordinate)
                        }
                    }
                    .padding(14)
                    .background(
                        Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.panel))

                    contents
                    priceRow
                }
                .padding(.horizontal, Spacing.l)
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var contents: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What you could get").font(.headline)
            Text(model.summary).foregroundStyle(.secondary)
            if !model.dietary.isEmpty {
                HStack(spacing: 6) {
                    ForEach(model.dietary) { tag in
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
    }

    private var priceRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Price").font(.headline)
                Text("You save \(model.savingsPercent)%").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            PriceStack(price: model.price, estimatedValue: model.estimatedValue, size: .title2)
        }
    }

    private func reserveBar(_ reserve: ReserveModel) -> some View {
        VStack(spacing: Spacing.s) {
            if model.canReserve {
                Stepper(
                    "Quantity: \(reserve.quantity)", value: Bindable(reserve).quantity, in: 1...reserve.maxQuantity)
            }
            Button {
                Task { await reserve.reserve() }
            } label: {
                Text(model.reserveButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.splashTeal)
            .disabled(!model.canReserve || reserve.isReserving)
            .accessibilityIdentifier("offerDetail.reserve")
        }
        .padding(Spacing.l)
        .background(.bar)
    }
}

private struct InfoRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: symbol)
                .foregroundStyle(Color.splashTeal)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A small non-interactive map with the restaurant's pin.
private struct LocationPreview: View {
    let name: String
    let coordinate: Coordinate

    var body: some View {
        let location = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        Map(
            initialPosition: .region(
                MKCoordinateRegion(center: location, latitudinalMeters: 600, longitudinalMeters: 600)),
            interactionModes: []
        ) {
            Marker(name, systemImage: "bag.fill", coordinate: location).tint(Color.splashTeal)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tile))
        .accessibilityLabel("Map showing \(name)")
    }
}
