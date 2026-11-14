//  KtancraftApp.swift
//  Ktancraft
//  Ktan Labs
//
//  Ktancraft: a complete voxel sandbox that runs on the phone itself. No game
//  files to prepare, no computer needed — every texture and every world is
//  generated on the device.

import SwiftUI

@main
struct KtancraftApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}

struct RootView: View {
    @StateObject private var settings = GameSettings()
    @State private var launch: GameLaunch?

    var body: some View {
        ZStack {
            if let launch {
                GameView(launch: launch, settings: settings) {
                    self.launch = nil
                }
                .id(launch.id)
                .transition(.opacity)
            } else {
                MenuView(settings: settings) { request in
                    launch = request
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: launch?.id)
    }
}
