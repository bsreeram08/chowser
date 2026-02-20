//
//  ChowserApp.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI

@main
struct ChowserApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var openedURL: URL?

    var body: some Scene {
        Window("Chowser", id: "picker") {
            ContentView(openedURL: $openedURL)
                .onOpenURL { url in
                    openedURL = url
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 600, height: 500)
    }
}
