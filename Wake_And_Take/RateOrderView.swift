//
//  RateOrderView.swift
//  Wake_And_Take
//
//  User Journey 7: after picking up, a customer rates their bag.
//  Ratings feed the store scores shown in Discover.
//

import SwiftUI

struct RateOrderView: View {
    let store: BagStore
    let reservationID: Reservation.ID
    var initialStars = 0

    @State private var overall = 0
    @State private var quality = 0
    @State private var value = 0
    @State private var pickup = 0
    @State private var tags: Set<ReviewTag> = []
    @State private var comment = ""
    @State private var submitted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let r = store.reservation(id: reservationID) {
                    if submitted {
                        thanks(r)
                    } else {
                        form(r)
                    }
                } else {
                    ContentUnavailableView("Order not found", systemImage: "bag")
                }
            }
            .navigationTitle(submitted ? "" : "Rate your bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not now") { dismiss() }
                    }
                }
            }
        }
        .tint(.splashTeal)
        .onAppear { if overall == 0 { overall = initialStars } }
        .sensoryFeedback(.success, trigger: submitted)
    }

    private func form(_ r: Reservation) -> some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Text("How was your bag from \(r.bag.store)?")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    StarRating(rating: $overall, size: 36, label: "Overall")
                    Text(overallCaption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Details") {
                detailRow("Food quality", $quality)
                detailRow("Value for money", $value)
                detailRow("Pickup experience", $pickup)
            }

            Section("What stood out?") {
                FlowTags(selection: $tags)
                    .padding(.vertical, 4)
            }

            Section {
                TextField("Tell the store more (optional)", text: $comment, axis: .vertical)
                    .lineLimit(3...6)
            } footer: {
                Text("Your rating is shared with \(r.bag.store) and counts toward its score in Discover.")
            }

            Section {
                Button {
                    submit()
                } label: {
                    Text("Submit rating")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(overall == 0)
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

    private var overallCaption: String {
        switch overall {
        case 1: "Not great"
        case 2: "Could be better"
        case 3: "It was OK"
        case 4: "Really good"
        case 5: "Loved it!"
        default: "Tap a star to rate"
        }
    }

    private func thanks(_ r: Reservation) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.splashTeal)
            Text("Thanks for your rating!").font(.title2.weight(.bold))
            if let bag = store.bag(id: r.bag.id) {
                Text("\(bag.store) is now rated \(String(format: "%.1f", bag.rating)) from \(bag.reviewCount) ratings.")
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
        .padding(24)
    }

    private func submit() {
        let review = Review(overall: overall, quality: quality, value: value, pickup: pickup,
                            tags: tags, comment: comment.trimmingCharacters(in: .whitespacesAndNewlines))
        if store.submitReview(review, for: reservationID) {
            withAnimation { submitted = true }
        } else {
            dismiss()
        }
    }
}

// MARK: - Components

struct StarRating: View {
    @Binding var rating: Int
    var size: CGFloat = 24
    var label = "Rating"

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yolk : Color.secondary.opacity(0.5))
                    .onTapGesture { rating = star }
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(rating == 0 ? "Not rated" : "\(rating) of 5 stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(5, rating + 1)
            case .decrement: rating = max(1, rating - 1)
            @unknown default: break
            }
        }
    }
}

/// Toggleable chips for quick feedback.
struct FlowTags: View {
    @Binding var selection: Set<ReviewTag>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(ReviewTag.allCases) { tag in
                let isOn = selection.contains(tag)
                Button {
                    if isOn { selection.remove(tag) } else { selection.insert(tag) }
                } label: {
                    Label(tag.rawValue, systemImage: tag.isPositive ? "hand.thumbsup" : "hand.thumbsdown")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isOn ? Color.splashTeal : Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Read-only stars for showing a rating that's already been given.
struct StarsDisplay: View {
    let rating: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yolk : Color.secondary.opacity(0.5))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(rating) of 5 stars")
    }
}

#Preview {
    let store = BagStore(defaults: UserDefaults(suiteName: "preview")!)
    let r = store.reserve(store.bags[0].id, quantity: 1)!
    store.markCollected(r.id)
    return RateOrderView(store: store, reservationID: r.id)
}
