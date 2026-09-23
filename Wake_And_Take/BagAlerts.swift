//
//  BagAlerts.swift
//  Wake_And_Take
//
//  Local notifications for favorite stores: "your store's bags are open".
//

import UserNotifications

enum BagAlerts {
    private static var center: UNUserNotificationCenter { .current() }
    private static let idPrefix = "drop-"

    /// Asks for permission the first time; returns whether alerts can be shown.
    static func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Schedules an alert for when each bag's pickup window opens.
    static func schedule(_ bags: [SurplusBag], now: Date = .now) {
        for bag in bags where bag.pickupStart > now && !bag.isSoldOut {
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: bag.pickupStart.timeIntervalSince(now), repeats: false
            )
            center.add(UNNotificationRequest(identifier: idPrefix + bag.id.uuidString,
                                             content: content(for: bag), trigger: trigger))
        }
    }

    static func cancel(_ bags: [SurplusBag]) {
        center.removePendingNotificationRequests(withIdentifiers: bags.map { idPrefix + $0.id.uuidString })
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Sends a sample alert a few seconds from now so you can see what one looks like.
    static func sendPreview(for bag: SurplusBag) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        center.add(UNNotificationRequest(identifier: "preview-\(UUID().uuidString)",
                                         content: content(for: bag), trigger: trigger))
    }

    private static func content(for bag: SurplusBag) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(bag.store) has bags ready"
        content.body = "\(bag.name) for \(bag.price.formatted(.currency(code: "USD"))) "
            + "(was \(bag.originalPrice.formatted(.currency(code: "USD")))). Pick up \(bag.pickupWindow)."
        content.sound = .default
        return content
    }
}

/// Shows alerts as banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
