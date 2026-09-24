//
//  NYCalendar.swift
//  WakeAndTakeKit
//
//  All business calendar math happens in New York time, never `Calendar.current`.
//

import Domain
import Foundation

public enum NYCalendar {
    public static let timeZone = TimeZone(identifier: "America/New_York")!

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// The New York day `date` falls on.
    public static func dayKey(for date: Date) -> DayKey {
        DayKey(date, calendar: calendar)
    }

    /// The New York day after `key`.
    public static func day(after key: DayKey) -> DayKey {
        guard let start = startOfDay(key),
            let next = calendar.date(byAdding: .day, value: 1, to: start)
        else { return key }
        return dayKey(for: next)
    }

    /// Midnight at the start of `key` in New York.
    public static func startOfDay(_ key: DayKey) -> Date? {
        date(on: key, hour: 0, minute: 0)
    }

    /// A New York wall-clock time on `key`, e.g. 7:30 on 2026-09-25.
    public static func date(on key: DayKey, hour: Int, minute: Int) -> Date? {
        let parts = key.rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour, minute: minute)
        )
    }
}
