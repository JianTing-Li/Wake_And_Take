//
//  CommuteMatcher.swift
//  WalkAndTakeKit
//

import Foundation

public enum CommuteMatcher {
    /// The commute window on `day`, or nil if it isn't a commute day or the times are invalid.
    public static func commuteWindow(
        for profile: CommuteProfile,
        on day: Date,
        calendar: Calendar
    ) -> ClosedRange<Date>? {
        guard profile.isValid, profile.commuteDays.contains(calendar.component(.weekday, from: day)),
            let leave = time(profile.leaveMinutes, on: day, calendar: calendar),
            let arrive = time(profile.arriveMinutes, on: day, calendar: calendar)
        else { return nil }
        return leave...arrive
    }

    /// True when the pickup window overlaps the commute on the pickup's own day,
    /// so tomorrow's bags are matched against tomorrow's commute.
    public static func fits(_ window: PickupWindow, profile: CommuteProfile, calendar: Calendar) -> Bool {
        guard let commute = commuteWindow(for: profile, on: window.start, calendar: calendar) else { return false }
        return window.start < commute.upperBound && window.end > commute.lowerBound
    }

    /// Wall-clock time on `day` (DST-safe, unlike adding seconds to midnight).
    private static func time(_ minutes: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }
}
