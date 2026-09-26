//
//  MapBrowseView.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import MapKit
import SwiftUI

struct MapBrowseView: View {
    @Bindable var model: MapBrowseModel
    let onOpenOffer: (String) -> Void

    @State private var position: MapCameraPosition = .automatic
    @State private var didCenter = false

    var body: some View {
        Map(position: $position) {
            MapCircle(center: model.center.clLocation, radius: model.maxDistanceMiles * metersPerMile)
                .foregroundStyle(Color.splashTeal.opacity(0.08))
                .stroke(Color.splashTeal.opacity(0.5), lineWidth: 1.5)

            Annotation("You", coordinate: model.center.clLocation, anchor: .center) {
                Circle()
                    .fill(.blue)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(radius: 2)
                    .accessibilityLabel("Your location")
            }
            .annotationTitles(.hidden)

            ForEach(model.pins) { pin in
                Annotation(pin.accessibilityText, coordinate: pin.coordinate.clLocation, anchor: .bottom) {
                    PricePin(
                        category: pin.category, price: pin.price, state: pin.state,
                        isSelected: pin.offerID == model.selectedOfferID, accessibilityText: pin.accessibilityText
                    )
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) { model.select(pin.offerID) }
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation { position = homeRegion }
            } label: {
                Image(systemName: "location.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .padding(Spacing.m)
            .accessibilityLabel("Recenter map")
        }
        .safeAreaInset(edge: .top) {
            if model.showsDayPicker {
                Picker("Day", selection: $model.day) {
                    ForEach(MapBrowseModel.Day.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 72)
                .padding(.top, Spacing.xs)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if let card = model.selectedCard, let id = model.selectedOfferID {
                    MapBagCard(card) {
                        onOpenOffer(id)
                    } onClose: {
                        withAnimation { model.select(nil) }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    legend
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xs)
        }
        .onAppear {
            guard !didCenter else { return }
            position = homeRegion
            didCenter = true
        }
        .onChange(of: model.center) { position = homeRegion }
        .onChange(of: model.maxDistanceMiles) { position = homeRegion }
    }

    private let metersPerMile = 1609.34

    /// Frames the distance circle with a little room around it.
    private var homeRegion: MapCameraPosition {
        let meters = max(model.maxDistanceMiles * metersPerMile * 2.3, 1200)
        return .region(
            MKCoordinateRegion(center: model.center.clLocation, latitudinalMeters: meters, longitudinalMeters: meters))
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(model.availableCount) bags within \(model.maxDistanceText) mi · tap a pin")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 14) {
                legendDot(.splashTeal, "Available now")
                legendDot(.orange, "Opens later")
                legendDot(.gray, "Gone")
                legendDot(.blue, "You")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

extension Coordinate {
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
