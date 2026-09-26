//
//  TimeText.swift
//  WalkAndTakeKit
//
//  Deterministic US-English time and date text in the calendar's time zone.
//  Built from calendar components (not locale formatters) so copy is identical
//  on every device and in tests.
//

import Foundation

public enum TimeText {
    private static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "7:30 AM", "12:00 PM", "11:59 PM".
    public static func time(_ date: Date, calendar: Calendar) -> String {
        let (clock, meridiem) = parts(date, calendar: calendar)
        return "\(clock) \(meridiem)"
    }

    /// "7:30–10:00 AM" when both ends share AM/PM, otherwise "11:30 AM–2:00 PM".
    public static func range(_ window: PickupWindow, calendar: Calendar) -> String {
        let (startClock, startMeridiem) = parts(window.start, calendar: calendar)
        let (endClock, endMeridiem) = parts(window.end, calendar: calendar)
        if startMeridiem == endMeridiem {
            return "\(startClock)–\(endClock) \(endMeridiem)"
        }
        return "\(startClock) \(startMeridiem)–\(endClock) \(endMeridiem)"
    }

    /// "Fri Sep 25".
    public static func shortDate(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.weekday, .month, .day], from: date)
        return "\(weekdays[(c.weekday ?? 1) - 1]) \(months[(c.month ?? 1) - 1]) \(c.day ?? 1)"
    }

    private static func parts(_ date: Date, calendar: Calendar) -> (clock: String, meridiem: String) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let hour = c.hour ?? 0
        let minute = c.minute ?? 0
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return (String(format: "%d:%02d", hour12, minute), hour < 12 ? "AM" : "PM")
    }
}
