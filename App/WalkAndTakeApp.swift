//
//  WalkAndTakeApp.swift
//  WalkAndTake
//
//  Created by Jian Ting Li on 9/23/26.
//

import SwiftUI
import UserNotifications

@main
struct WalkAndTakeApp: App {
    private let dependencies: AppDependencies

    init() {
        dependencies = AppDependencies()
        UNUserNotificationCenter.current().delegate = dependencies.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            AppRoot(dependencies: dependencies)
        }
    }
}
