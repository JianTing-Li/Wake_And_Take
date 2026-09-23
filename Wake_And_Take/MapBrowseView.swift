//
//  MapBrowseView.swift
//  Wake_And_Take
//
//  User Journey 6: a customer browses nearby stores with bags on a map
//  and taps a pin to view and reserve a bag.
//

import SwiftUI
import MapKit

struct MapBrowseView: View {
    let store: BagStore

    /// Demo "you are here" spot (Court Square, Long Island City).
    static let home = CLLocationCoordinate2D(latitude: 40.7465, longitude: -73.9420)

    @State private var position: MapCameraPosition = .automatic
    @State private var didCenter = false
    @State private var selectedID: SurplusBag.ID?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let bags = store.bags.filter { store.profile.matches($0) }
            let selected = selectedID.flatMap { store.bag(id: $0) }

            Map(position: $position) {
                MapCircle(center: Self.home, radius: store.profile.maxDistanceMiles * 1609.34)
                    .foregroundStyle(Color.splashTeal.opacity(0.08))
                    .stroke(Color.splashTeal.opacity(0.5), lineWidth: 1.5)

                Annotation("You", coordinate: Self.home) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 2)
                }

                ForEach(bags) { bag in
                    Annotation(bag.store, coordinate: bag.coordinate, anchor: .bottom) {
                        PricePin(bag: bag, now: now, isSelected: bag.id == selectedID)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3)) { selectedID = bag.id }
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
                .padding(12)
                .accessibilityLabel("Recenter map")
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if let selected {
                        MapBagCard(bag: selected, now: now) {
                            withAnimation { selectedID = nil }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        legend(count: bags.filter { $0.isAvailable(at: now) }.count)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didCenter else { return }
            position = homeRegion
            didCenter = true
        }
    }

    /// Frames the detour circle with a little room around it.
    private var homeRegion: MapCameraPosition {
        let meters = max(store.profile.maxDistanceMiles * 1609.34 * 2.3, 1200)
        return .region(MKCoordinateRegion(center: Self.home, latitudinalMeters: meters, longitudinalMeters: meters))
    }

    private func legend(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count) bags within \(store.profile.maxDistanceMiles.formatted(.number.precision(.fractionLength(0...2)))) mi · tap a pin")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 14) {
                legendDot(.splashTeal, "Available now")
                legendDot(.orange, "Opens later")
                legendDot(.gray, "Gone")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Pin

struct PricePin: View {
    let bag: SurplusBag
    let now: Date
    let isSelected: Bool

    private var color: Color {
        if !bag.isAvailable(at: now) { return .gray }
        return now < bag.pickupStart ? .orange : .splashTeal
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: bag.category.symbol).font(.caption2)
                Text(bag.isAvailable(at: now) ? bag.price.formatted(.currency(code: "USD")) : "Gone")
                    .font(.caption.weight(.bold))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(color, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: isSelected ? 3 : 1.5))

            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
        }
        .foregroundStyle(.white)
        .scaleEffect(isSelected ? 1.2 : 1, anchor: .bottom)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .zIndex(isSelected ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bag.store), \(bag.urgency(at: now)), \(bag.price.formatted(.currency(code: "USD")))")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Card

struct MapBagCard: View {
    let bag: SurplusBag
    let now: Date
    let onClose: () -> Void

    var body: some View {
        let available = bag.isAvailable(at: now)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: bag.category.symbol)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(bag.category.tint, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(bag.store).font(.headline)
                    Text(bag.name).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(bag.urgency(at: now)) · \(String(format: "%.1f mi", bag.distanceMiles))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(bag.endsSoon(at: now) ? .red : .secondary)
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            HStack {
                Text(bag.originalPrice, format: .currency(code: "USD"))
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Text(bag.price, format: .currency(code: "USD"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.splashTeal)
                Spacer()
                NavigationLink(value: bag.id) {
                    Text(available ? "View bag" : "See details")
                        .font(.headline)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(available ? Color.splashTeal : .gray, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}

#Preview {
    let store = BagStore(defaults: UserDefaults(suiteName: "preview")!)
    return NavigationStack {
        MapBrowseView(store: store)
            .navigationDestination(for: SurplusBag.ID.self) { BagDetailView(store: store, bagID: $0) }
    }
    .tint(.splashTeal)
}
