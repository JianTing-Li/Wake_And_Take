//
//  AppRoot.swift
//  WalkAndTake
//
//  Switches on the user's role, overlays the splash, and triggers rollover on
//  launch, when the app becomes active, on significant time changes, and when
//  the debug clock moves.
//

import CustomerFeatures
import Domain
import MockData
import Platform
import SwiftUI
import UIKit

struct AppRoot: View {
    let dependencies: AppDependencies

    @State private var showSplash = AppRoot.showsSplashOnLaunch
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch dependencies.role {
            case .customer:
                CustomerShell(dependencies: dependencies)
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(\.featureFlags, dependencies.flags)
        .task { await dependencies.runRollover(reason: "launch") }
        .task { await dependencies.rollover.syncAlerts() }
        .task {
            let changes = NotificationCenter.default.notifications(
                named: UIApplication.significantTimeChangeNotification)
            for await _ in changes.map({ _ in () }) {
                await dependencies.runRollover(reason: "significant time change")
            }
        }
        .task {
            for await _ in dependencies.clock.changes() {
                await dependencies.runRollover(reason: "clock changed")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await dependencies.runRollover(reason: "became active") }
        }
    }

    private static var showsSplashOnLaunch: Bool {
        #if DEBUG
            !LaunchOptions.current.skipSplash
        #else
            true
        #endif
    }
}
