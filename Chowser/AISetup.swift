import AppKit

/// "Set up with AI" as one action instead of a hidden onboarding step: start the
/// localhost-only API, copy a setup prompt (with the token) to the clipboard, and say
/// what to do next. The prompt is built in rather than fetched, so the token is never
/// appended to text Chowser didn't ship.
@MainActor
enum AISetup {
    static func run() {
        let server = MCPServer.shared
        if !server.isRunning { server.start() }

        let alert = NSAlert()
        if server.isRunning {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt(port: server.port, token: server.authToken), forType: .string)
            alert.messageText = "Setup prompt copied"
            alert.informativeText = """
            Paste it into Claude, ChatGPT, Cursor or any assistant that can run commands. It finds your browsers and profiles and asks before changing anything.

            The local API stays on until you stop it from the menu bar or Settings.
            """
        } else {
            alert.alertStyle = .warning
            alert.messageText = "Couldn't start the local API"
            alert.informativeText = "Another app may be using port \(server.port). Try again, or check Settings → General."
        }
        NSApp.activate()
        alert.runModal()
    }

    static func prompt(port: UInt16, token: String) -> String {
        """
        I have installed Chowser (bundle ID: in.sreerams.Chowser) on my Mac. It's a browser chooser app with an opt-in, localhost-only HTTP API server for configuration.

        Your goal is to configure my browsers and routing rules.

        0. **Check your tools first**: if you have no shell/filesystem access and no HTTP fetch tool, say so and stop — you can't complete this. If you have HTTP fetch but no filesystem access (e.g. a plain chat app), skip step 3's filesystem scan and ask me for my browsers/profiles directly instead.
        1. **Authenticate**: every request needs the exact header `Authorization: Bearer <token>` (the token is below) — no other header name works.
        2. **Discover API Schema**: Call `GET /status` — its `endpoints` field lists every available endpoint and required JSON fields for this running version.
        3. **Discover Browsers**: Scan my Mac for browsers and profiles (Chrome, Brave, Edge, Vivaldi, Arc, Dia, Opera, Firefox, Zen, Safari), or ask me if you can't scan the filesystem.
        4. **Configure**: Use `POST /browsers` to add profiles and `POST /rules` to set routing. Use the credentials below.
        5. **Rewrites (optional)**: Offer to open `chowser://settings` so I can review and install signed predefined rewrites in Chowser. Do not copy raw catalog JSON into `POST /rewrites`; that bypasses signature verification and signed provenance.
        6. **Confirm**: Show a summary and ask for confirmation before making any changes.

        **Note**: Direct profile switching is unsupported for Arc and Dia browsers; do not attempt to configure specific profiles for these apps.

        ---
        API server: http://localhost:\(port)
        Authorization header: Bearer \(token)
        """
    }
}
