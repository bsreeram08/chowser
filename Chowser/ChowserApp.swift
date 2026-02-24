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

    var body: some Scene {
        // All window management (picker, settings) is handled in AppDelegate.
        // We use Settings { EmptyView() } purely as a required scene placeholder.
        // The actual Settings UI is hosted in an NSWindowController in AppDelegate,
        // which gives us explicit control over when it opens (never auto-presents).
        Settings {
            EmptyView()
        }
    }
}
