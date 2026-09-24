//
//  ProfileView.swift
//  WakeAndTakeKit
//

import DesignSystem
import Domain
import Platform
import SwiftUI

public struct ProfileView: View {
    @Bindable var model: ProfileModel
    @Bindable var navigation: CustomerNavigation
    let developerDestination: ((ProfileRoute) -> AnyView)?

    public init(
        model: ProfileModel, navigation: CustomerNavigation,
        developerDestination: ((ProfileRoute) -> AnyView)? = nil
    ) {
        self.model = model
        self.navigation = navigation
        self.developerDestination = developerDestination
    }

    public var body: some View {
        NavigationStack(path: $navigation.profilePath) {
            Group {
                switch model.state {
                case .loading: LoadingView()
                case .failed(let message):
                    EmptyStateView(
                        "Something went wrong", systemImage: "exclamationmark.triangle", message: message,
                        actionTitle: "Try again"
                    ) { Task { await model.load() } }
                case .loaded: form
                }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: ProfileRoute.self) { route in
                developerDestination?(route) ?? AnyView(EmptyView())
            }
        }
        .tint(.splashTeal)
        .task { await model.run() }
    }

    private var form: some View {
        Form {
            if model.showsImpact {
                Section {
                    ImpactCard(impact: model.impact)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Your impact")
                }
            }

            Section("About you") {
                TextField("Your name", text: $model.preferences.name)
                    .textContentType(.givenName)
                LabeledContent("Home area") {
                    TextField("Neighborhood", text: $model.preferences.homeArea)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Picker("Max distance", selection: $model.preferences.maxDistanceMiles) {
                    ForEach(model.distanceOptions, id: \.self) { Text(model.distanceLabel($0)).tag($0) }
                }
            } header: {
                Text("Distance")
            } footer: {
                Text("Discover hides bags farther than this from you.")
            }

            if model.showsDietary { dietarySection }
            if model.showsCommute { CommuteSection(model: model) }
            resetSection
            if developerDestination != nil { developerSection }
        }
    }

    private var dietarySection: some View {
        Section {
            ForEach(DietaryTag.allCases) { tag in
                Toggle(
                    isOn: Binding(
                        get: { model.preferences.dietary.contains(tag) },
                        set: { model.setDietary(tag, $0) })
                ) {
                    Label(tag.label, systemImage: tag.symbol)
                }
            }
        } header: {
            Text("Dietary preferences")
        } footer: {
            Text(
                "Discover only shows bags that fit every preference you turn on. "
                    + "Surprise bags vary, so check with the store if you have an allergy.")
        }
    }

    /// DEBUG only: the app passes these tools in debug builds.
    private var developerSection: some View {
        Section {
            NavigationLink(value: ProfileRoute.timeTravel) {
                Label("Time travel", systemImage: "clock.arrow.2.circlepath")
            }
            NavigationLink(value: ProfileRoute.seedMap) {
                Label("Seed map", systemImage: "map")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Debug builds only.")
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                model.confirmingReset = true
            } label: {
                HStack {
                    Label("Reset demo data", systemImage: "arrow.counterclockwise")
                    if model.isResetting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(model.isResetting)
            .confirmationDialog(
                "Reset all demo data?", isPresented: $model.confirmingReset, titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { Task { await model.resetDemoData() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Orders, ratings, favorites and preferences will be erased and today's bags restocked.")
            }
            .alert("Reset didn't finish", isPresented: $model.resetFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
        } footer: {
            Text("Starts the demo over with fresh bags from every store.")
        }
    }
}

/// "Morning commute" (behind the commute flag).
private struct CommuteSection: View {
    @Bindable var model: ProfileModel

    var body: some View {
        Section {
            DatePicker("Leave home", selection: time(\.leaveMinutes), displayedComponents: .hourAndMinute)
            DatePicker("Arrive at work", selection: time(\.arriveMinutes), displayedComponents: .hourAndMinute)

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Commute days")
                WeekdayPicker(selection: $model.commute.commuteDays, calendar: NYCalendar.calendar)
            }
            .padding(.vertical, 4)

            Picker("Getting there", selection: $model.commute.travelMode) {
                ForEach(TravelMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
        } header: {
            Text("Morning commute")
        } footer: {
            if model.commute.isValid {
                Text("Bags you can pick up during your commute get a “Fits your commute” tag in Discover.")
            } else {
                Label(
                    "Your arrival time needs to be after you leave home.", systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.red)
            }
        }
        .environment(\.timeZone, NYCalendar.timeZone)
    }

    /// Bridges minutes-after-midnight (New York) to a Date for the time pickers.
    private func time(_ keyPath: WritableKeyPath<CommuteProfile, Int>) -> Binding<Date> {
        Binding {
            model.time(forMinutes: model.commute[keyPath: keyPath])
        } set: { date in
            model.commute[keyPath: keyPath] = model.minutes(from: date)
        }
    }
}
