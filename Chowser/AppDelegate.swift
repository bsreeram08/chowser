//
//  AppDelegate.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        BrowserManager.shared.currentURL = url
        showPicker()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When dock icon is clicked (if visible), show settings
        if !flag {
            openSettings()
        }
        return true
    }
    
    // MARK: - Status Bar
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Chowser")
            button.image?.size = NSSize(width: 16, height: 16)
            button.toolTip = "Chowser — Browser Chooser"
        }
        
        let menu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "About Chowser", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let defaultBrowserItem = NSMenuItem(title: "Set as Default Browser…", action: #selector(setDefaultBrowser), keyEquivalent: "")
        defaultBrowserItem.target = self
        menu.addItem(defaultBrowserItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Chowser", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Actions
    
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc func openSettings() {
        NotificationCenter.default.post(name: Notification.Name("openSettingsWindow"), object: nil)
    }
    
    private func showPicker() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func setDefaultBrowser() {
        BrowserManager.setAsDefaultBrowser()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
