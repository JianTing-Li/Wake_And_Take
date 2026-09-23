//
//  Wake_And_TakeApp.swift
//  Wake_And_Take
//
//  Created by Jian Ting Li on 9/23/26.
//

import SwiftUI
import UserNotifications

@main
struct Wake_And_TakeApp: App {
    @State private var showSplash = true
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
