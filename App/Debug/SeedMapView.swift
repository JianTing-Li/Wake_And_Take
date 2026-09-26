//
//  SeedMapView.swift
//  WalkAndTake
//
//  DEBUG: every seed restaurant on a map, with the service area, for sanity-checking
//  coordinates. Restaurants outside the 1.5 mi area are listed in red.
//

#if DEBUG
    import DesignSystem
    import Domain
    import MapKit
    import Platform
    import SwiftUI

    struct SeedMapView: View {
        let offers: any OfferRepository
        @State private var restaurants: [Restaurant] = []

        private let area = ServiceArea.longIslandCity

        var body: some View {
            let outside = restaurants.filter { !area.contains($0.coordinate) }
            Map(initialPosition: .region(region)) {
                MapCircle(center: location(area.center), radius: area.radiusMiles * 1609.34)
                    .foregroundStyle(Color.splashTeal.opacity(0.08))
                    .stroke(Color.splashTeal, lineWidth: 1.5)
                ForEach(restaurants) { restaurant in
                    Marker(restaurant.name, systemImage: "storefront", coordinate: location(restaurant.coordinate))
                        .tint(area.contains(restaurant.coordinate) ? Color.splashTeal : .red)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(restaurants.count) restaurants · \(outside.count) outside the service area")
                        .font(.subheadline.weight(.semibold))
                    ForEach(outside) { Text($0.name).font(.caption).foregroundStyle(.red) }
                }
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card))
                .padding(Spacing.l)
            }
            .navigationTitle("Seed map")
            .navigationBarTitleDisplayMode(.inline)
            .task { restaurants = (try? await offers.restaurants()) ?? [] }
        }

        private var region: MKCoordinateRegion {
            let meters = area.radiusMiles * 1609.34 * 2.4
            return MKCoordinateRegion(
                center: location(area.center), latitudinalMeters: meters, longitudinalMeters: meters)
        }

        private func location(_ c: Coordinate) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
        }
    }
#endif
