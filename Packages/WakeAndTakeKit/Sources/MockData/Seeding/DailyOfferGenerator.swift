//
//  DailyOfferGenerator.swift
//  WakeAndTakeKit
//

import Domain
import Foundation
import Platform

/// Turns templates into concrete offers for one New York day.
public enum DailyOfferGenerator {
    public static func offers(from templates: [OfferTemplate], on day: DayKey) -> [Offer] {
        templates.compactMap { offer(from: $0, on: day) }
    }

    /// Nil only if the template's times are malformed (validation rejects those first).
    public static func offer(from template: OfferTemplate, on day: DayKey) -> Offer? {
        guard let startMinutes = template.startMinutes, let endMinutes = template.endMinutes,
            let start = NYCalendar.date(on: day, hour: startMinutes / 60, minute: startMinutes % 60),
            let end = NYCalendar.date(on: day, hour: endMinutes / 60, minute: endMinutes % 60)
        else { return nil }

        return Offer(
            id: Offer.makeID(templateID: template.id, day: day),
            templateID: template.id,
            restaurantID: template.restaurantID,
            name: template.name,
            category: template.category,
            summary: template.summary,
            dietary: template.dietary,
            price: template.price,
            estimatedValue: template.estimatedValue,
            quantityTotal: template.quantityTotal,
            quantityReserved: template.simulatedReservedCount,
            pickupWindow: PickupWindow(start: start, end: end)
        )
    }
}
