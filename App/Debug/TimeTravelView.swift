//
//  TimeTravelView.swift
//  WalkAndTake
//
//  DEBUG: jump the app's clock to interesting New York times. Moving the clock
//  triggers rollover (AppRoot watches clock changes), so crossing midnight or
//  8 PM behaves exactly as it would in real time.
//

#if DEBUG
    import DesignSystem
    import Domain
    import Platform
    import SwiftUI

    struct TimeTravelView: View {
        let clock: AdjustableClock

        private let presets: [(label: String, hour: Int, minute: Int)] = [
            ("Breakfast · 7:45 AM", 7, 45),
            ("Lunch · 12:30 PM", 12, 30),
            ("Tomorrow's bags open · 8:15 PM", 20, 15),
            ("Just before midnight · 11:50 PM", 23, 50),
        ]

        var body: some View {
            TimelineView(.animation(minimumInterval: 1)) { _ in
                let now = clock.now
                List {
                    Section("App time (New York)") {
                        LabeledContent("Day", value: TimeText.shortDate(now, calendar: NYCalendar.calendar))
                        LabeledContent("Time", value: TimeText.time(now, calendar: NYCalendar.calendar))
                        LabeledContent("Mode", value: clock.isLive ? "Live" : "Time traveling")
                    }

                    Section {
                        ForEach(presets, id: \.label) { preset in
                            Button(preset.label) { jump(hour: preset.hour, minute: preset.minute, from: now) }
                        }
                        Button("Next day, same time") { clock.advance(by: 24 * 60 * 60) }
                    } header: {
                        Text("Jump to (today, New York)")
                    } footer: {
                        Text("Time keeps running from where you jump. Rollover runs automatically.")
                    }

                    Section {
                        Button("Back to live time", role: .destructive) { clock.resetToLive() }
                            .disabled(clock.isLive)
                    }
                }
            }
            .navigationTitle("Time travel")
            .navigationBarTitleDisplayMode(.inline)
        }

        private func jump(hour: Int, minute: Int, from now: Date) {
            let today = NYCalendar.dayKey(for: now)
            if let target = NYCalendar.date(on: today, hour: hour, minute: minute) {
                clock.travel(to: target)
            }
        }
    }
#endif
