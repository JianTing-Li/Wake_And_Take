//
//  WeekdayPicker.swift
//  WakeAndTakeKit
//

import SwiftUI

/// Seven round day toggles, starting on the calendar's first weekday.
/// Selection uses calendar weekday numbers (1 = Sunday … 7 = Saturday).
public struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    /// Display only: which day starts the week and the day letters.
    let calendar: Calendar

    public init(selection: Binding<Set<Int>>, calendar: Calendar = Calendar(identifier: .gregorian)) {
        _selection = selection
        self.calendar = calendar
    }

    public var body: some View {
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

#Preview("Light") {
    @Previewable @State var days: Set<Int> = [2, 3, 4, 5, 6]
    WeekdayPicker(selection: $days).padding()
}

#Preview("Dark · large text") {
    @Previewable @State var days: Set<Int> = [1, 7]
    WeekdayPicker(selection: $days)
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility1)
}
