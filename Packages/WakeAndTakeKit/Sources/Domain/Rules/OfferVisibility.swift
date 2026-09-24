//
//  OfferVisibility.swift
//  WakeAndTakeKit
//
//  One rule for Discover, Map, Favorites and reserving.
//

import Foundation

public enum OfferVisibility {
    /// From this New York hour, tomorrow's offers are shown and reservable.
    public static let tomorrowCutoffHour = 20

    /// Whether tomorrow's offers are visible at `now`.
    public static func showsTomorrow(at now: Date, calendar: Calendar) -> Bool {
        calendar.component(.hour, from: now) >= tomorrowCutoffHour
    }

    /// Visible if the window is on today's date, or on tomorrow's date once
    /// it's `tomorrowCutoffHour` or later. Past and later days are never visible.
    public static func isVisible(_ window: PickupWindow, at now: Date, calendar: Calendar) -> Bool {
        let windowDay = calendar.startOfDay(for: window.start)
        let today = calendar.startOfDay(for: now)
        if windowDay == today { return true }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return false }
        return windowDay == tomorrow && showsTomorrow(at: now, calendar: calendar)
    }

    public static func isVisible(_ offer: Offer, at now: Date, calendar: Calendar) -> Bool {
        isVisible(offer.pickupWindow, at: now, calendar: calendar)
    }
}
