//
//  PickupDayFormatter.swift
//  WakeAndTakeKit
//
//  The single source of day-aware pickup copy, so a window is never
//  ambiguous about which day it's on.
//

import Foundation

public enum PickupDayFormatter {
    /// Today's windows starting at or after this hour are "Tonight".
    public static let tonightStartHour = 17

    /// Which day a window falls on, relative to `now`.
    public enum Day: Hashable, Sendable {
        case today, tonight, tomorrow
        /// Any other day (e.g. a past order); carries the window start.
        case other(Date)
    }

    /// Classifies the window's start day relative to `now`.
    public static func day(of window: PickupWindow, now: Date, calendar: Calendar) -> Day {
        let windowDay = calendar.startOfDay(for: window.start)
        let today = calendar.startOfDay(for: now)
        if windowDay == today {
            return calendar.component(.hour, from: window.start) >= tonightStartHour ? .tonight : .today
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), windowDay == tomorrow {
            return .tomorrow
        }
        return .other(window.start)
    }

    /// "Today", "Tonight", "Tomorrow", or "Fri Sep 25".
    public static func dayLabel(for window: PickupWindow, now: Date, calendar: Calendar) -> String {
        switch day(of: window, now: now, calendar: calendar) {
        case .today: "Today"
        case .tonight: "Tonight"
        case .tomorrow: "Tomorrow"
        case .other(let date): TimeText.shortDate(date, calendar: calendar)
        }
    }

    /// Card copy: "Today · 7:30–10:00 AM", "Tomorrow · 7:30–10:00 AM", or, once the
    /// window is open, "Tonight · until 11:59 PM".
    public static func short(_ window: PickupWindow, now: Date, calendar: Calendar) -> String {
        let label = dayLabel(for: window, now: now, calendar: calendar)
        if window.isOpen(at: now) {
            return "\(label) · until \(TimeText.time(window.end, calendar: calendar))"
        }
        return "\(label) · \(TimeText.range(window, calendar: calendar))"
    }

    /// Full-date copy for detail and order screens:
    /// "Pick up tomorrow, Fri Sep 25, 7:30–10:00 AM".
    public static func full(_ window: PickupWindow, now: Date, calendar: Calendar) -> String {
        let date = TimeText.shortDate(window.start, calendar: calendar)
        let range = TimeText.range(window, calendar: calendar)
        switch day(of: window, now: now, calendar: calendar) {
        case .today: return "Pick up today, \(date), \(range)"
        case .tonight: return "Pick up tonight, \(date), \(range)"
        case .tomorrow: return "Pick up tomorrow, \(date), \(range)"
        case .other: return "Pick up \(date), \(range)"
        }
    }

    /// Where `now` falls in the window: "Opens at 9:00 PM", "Opens tomorrow at 7:30 AM",
    /// "Ends in 25 min", "Ends at 10:00 AM", or "Pickup ended".
    public static func countdown(_ window: PickupWindow, now: Date, calendar: Calendar) -> String {
        if window.hasEnded(at: now) { return "Pickup ended" }
        if !window.hasStarted(at: now) {
            let time = TimeText.time(window.start, calendar: calendar)
            switch day(of: window, now: now, calendar: calendar) {
            case .today, .tonight: return "Opens at \(time)"
            case .tomorrow: return "Opens tomorrow at \(time)"
            case .other(let date): return "Opens \(TimeText.shortDate(date, calendar: calendar)) at \(time)"
            }
        }
        let minutes = Int(window.end.timeIntervalSince(now) / 60)
        if minutes < 60 { return "Ends in \(max(minutes, 1)) min" }
        return "Ends at \(TimeText.time(window.end, calendar: calendar))"
    }
}
