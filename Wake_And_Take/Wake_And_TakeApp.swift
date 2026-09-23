//
//  Wake_And_TakeApp.swift
//  Wake_And_Take
//
//  Created by Jian Ting Li on 9/23/26.
//

import SwiftUI

@main
struct Wake_And_TakeApp: App {
    @State private var showSplash = true

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
