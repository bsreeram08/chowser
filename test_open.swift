import AppKit
import Foundation

let bundleId = "com.google.Chrome" // Change to a browser you have with multiple profiles
let profileName = "Profile 1" // Change to a valid profile directory name
let urlString = "https://example.com"

guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
    print("App not found")
    exit(1)
}

guard let executableURL = Bundle(url: appURL)?.executableURL else {
    print("Executable not found")
    exit(1)
}

print("Launching \(executableURL.path)")
print("Args: --profile-directory=\(profileName) \(urlString)")

let process = Process()
process.executableURL = executableURL
process.arguments = ["--profile-directory=\(profileName)", urlString]

do {
    try process.run()
    print("Started")
} catch {
    print("Error: \(error)")
}

// Keep alive for a bit
Thread.sleep(forTimeInterval: 2)
