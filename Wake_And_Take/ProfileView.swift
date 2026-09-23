//
//  ProfileView.swift
//  Wake_And_Take
//
//  User Journey 4: a customer sets up their commute, location, and
//  dietary preferences so Discover shows bags that fit their morning.
//

import SwiftUI

struct ProfileView: View {
    @Bindable var store: BagStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ImpactCard(impact: store.impact)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Your impact")
                }

                Section("About you") {
                    TextField("Your name", text: $store.profile.name)
                        .textContentType(.givenName)
                    LabeledContent("Home area") {
                        TextField("Neighborhood", text: $store.profile.homeArea)
                            .multilineTextAlignment(.trailing)
                    }
                }

                commuteSection
                dietarySection
            }
            .navigationTitle("Profile")
        }
        .tint(.splashTeal)
    }

    // MARK: - Commute

    private var commuteSection: some View {
        Section {
            DatePicker("Leave home", selection: time(\.leaveMinutes), displayedComponents: .hourAndMinute)
            DatePicker("Arrive at work", selection: time(\.arriveMinutes), displayedComponents: .hourAndMinute)

            VStack(alignment: .leading, spacing: 10) {
                Text("Commute days")
                WeekdayPicker(selection: $store.profile.commuteDays)
            }
            .padding(.vertical, 4)

            Picker("Getting there", selection: $store.profile.travelMode) {
                ForEach(TravelMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }

            Picker("Max detour", selection: $store.profile.maxDistanceMiles) {
                ForEach(CommuteProfile.distanceOptions, id: \.self) { miles in
                    Text("\(miles.formatted(.number.precision(.fractionLength(0...2)))) mi").tag(miles)
                }
            }
        } header: {
            Text("Morning commute")
        } footer: {
            if store.profile.isCommuteValid {
                Text("Bags you can pick up during your commute get a “Fits your commute” tag in Discover. Stores farther than your max detour are hidden.")
            } else {
                Label("Your arrival time needs to be after you leave home.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    /// Bridges minutes-after-midnight to a Date for the time pickers.
    private func time(_ keyPath: WritableKeyPath<CommuteProfile, Int>) -> Binding<Date> {
        Binding {
            Calendar.current.startOfDay(for: .now).addingTimeInterval(Double(store.profile[keyPath: keyPath]) * 60)
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.profile[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }

    // MARK: - Dietary

    private var dietarySection: some View {
        Section {
            ForEach(DietaryTag.allCases) { tag in
                Toggle(isOn: Binding {
                    store.profile.dietary.contains(tag)
                } set: { on in
                    if on { store.profile.dietary.insert(tag) } else { store.profile.dietary.remove(tag) }
                }) {
                    Label(tag.label, systemImage: tag.symbol)
                }
            }
        } header: {
            Text("Dietary preferences")
        } footer: {
            Text("Discover only shows bags that fit every preference you turn on. Surprise bags vary, so check with the store if you have an allergy.")
        }
    }
}

/// Seven round day toggles, starting on the locale's first weekday.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    private var calendar: Calendar { .current }

    var body: some View {
        let first = calendar.firstWeekday
        let days = (0..<7).map { (first - 1 + $0) % 7 + 1 }

        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(calendar.veryShortWeekdaySymbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isOn ? Color.splashTeal : Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

#Preview {
    ProfileView(store: BagStore(defaults: UserDefaults(suiteName: "preview")!))
}
