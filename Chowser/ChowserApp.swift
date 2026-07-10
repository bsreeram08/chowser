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
    @State private var browserManager = BrowserManager.shared

    var body: some Scene {
        // All window management (picker, settings) is handled in AppDelegate.
        // We use Settings { EmptyView() } purely as a required scene placeholder.
        // The actual Settings UI is hosted in an NSWindowController in AppDelegate,
        // which gives us explicit control over when it opens (never auto-presents).
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Chowser") {
                    appDelegate.showAbout()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Open Clipboard URL...") {
                    appDelegate.openClipboardURL()
                }

                Menu("Focus Mode") {
                    if let temporaryRoute = browserManager.temporaryRoute {
                        Button("Clear Focus Mode") {
                            appDelegate.clearFocusMode()
                        }
                        Text("Active until \(temporaryRoute.expiresAt.formatted(date: .omitted, time: .shortened))")
                    } else {
                        ForEach(browserManager.configuredBrowsers.filter(\.isEnabled)) { browser in
                            Menu(browser.profile.map { "\(browser.name) (\($0))" } ?? browser.name) {
                                Button("1 Hour") {
                                    appDelegate.setFocusModeForOneHour(browser)
                                }
                                Button("Until Tomorrow") {
                                    appDelegate.setFocusModeUntilTomorrow(browser)
                                }
                            }
                        }
                    }
                }
            }

            CommandGroup(before: .appTermination) {
                Button("Diagnostics...") {
                    appDelegate.openDiagnostics()
                }
                Divider()
            }

            CommandGroup(replacing: .appTermination) {
                Button("Quit Chowser") {
                    appDelegate.quitApp()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
