<!-- Last verified: 2026-02-28 against commit 892fcaf -->

# Gotchas

Things that look wrong but are intentional, platform quirks, and subtle interactions that can trip up contributors.

---

## 1. Chromium profile handoff drops arguments

**Symptom**: Opening a URL with `NSWorkspace.openApplication` and Chromium ignores `--profile-directory`.

**Cause**: When Chromium is already running, `NSWorkspace.openApplication` sends the URL to the existing process via Apple Events. The existing process ignores `--profile-directory` from the new open request — it's only read on process startup.

**Workaround**: Use `Process` + `/usr/bin/open -n -a` which forces a new instance (`-n` flag). The new instance reads `--profile-directory` from its launch arguments.

**See**: `BrowserManager.swift` `open()` method, decision #2 in `decisions.md`.

---

## 2. NSPanel must be non-activating for Space switching

**Symptom**: Picker panel causes a Space switch animation when the user is in a full-screen app.

**Cause**: Standard `NSWindow` (and activating panels) trigger macOS's Space-switching behavior.

**Fix**: `ChowserPanel` uses `.nonactivatingPanel` style mask and `.canJoinAllSpaces | .fullScreenAuxiliary` collection behavior. The panel also sets level to `.mainMenu + 1` to appear above menu bar items.

**Caveat**: Because the panel is non-activating, `NSApp.activate()` is NOT called when showing the picker. This means the picker doesn't steal focus from the current app — it floats above it. Keyboard events are captured via `NSEvent.addLocalMonitorForEvents`.

---

## 3. applicationShouldHandleReopen race condition

**Symptom**: Occasionally, clicking the menu bar icon while a URL is being handled causes both the settings window and the picker to appear.

**Cause**: `applicationShouldHandleReopen` and `application(_:open:)` can fire in the same run loop iteration. The reopen handler would show settings before the URL handler can show the picker.

**Fix**: `applicationShouldHandleReopen` is intentionally NOT implemented. The `isHandlingURL` flag (reset after 1.0s) provides additional protection.

---

## 4. Two onboarding completion flags

**Symptom**: Onboarding state seems duplicated between `BrowserManager` and `OnboardingManager`.

**Cause**: Two separate UserDefaults keys exist:
- `"onboardingCompleted"` — read by `BrowserManager` for its own initialization logic
- `"hasCompletedOnboarding"` — read by `OnboardingManager` for window lifecycle

Both are set when onboarding finishes. This is not ideal but exists because the two managers were developed independently.

**Impact**: If you reset onboarding, you must reset BOTH flags. `OnboardingManager.resetOnboarding()` handles this.

---

## 5. Non-activating panel and text field focus

**Symptom**: Text fields in the picker (e.g., ConfigureRuleView) don't accept keyboard input.

**Cause**: The picker is a non-activating panel. SwiftUI text fields require the window to be key to accept input.

**Fix**: `ChowserPanel.canBecomeKey` returns `true` (overridden in the NSPanel subclass). The panel becomes key without becoming main or activating the app.

---

## 6. Arc browser profile detection works but selection may not

**Symptom**: Arc profiles are detected and shown in the UI, but selecting a specific profile may not switch to it.

**Cause**: Arc's internal architecture manages profiles/spaces independently. The `--profile-directory` flag is a Chromium convention that Arc partially supports but doesn't guarantee.

**Recommendation**: For Arc users, treat it as a single browser entry. Power users can try custom launch arguments.

---

## 7. Debounced saves and crash risk

**Symptom**: Changes made in the last 0.3 seconds before a crash are lost.

**Cause**: Browser and rule saves are debounced at 0.3s via `DispatchWorkItem`. If the app terminates within that window, the pending save never fires.

**Mitigation**: `flushPendingSaves()` is called before import/export operations and other critical paths. For normal usage, the 0.3s window is acceptable — the risk is primarily during rapid drag-reorder sequences.

---

## 8. Safari WebApps appear as separate browsers

**Symptom**: Safari-based WebApps (e.g., web apps added to Dock from Safari) show up in the installed browsers list.

**Cause**: macOS registers WebApps as capable of handling HTTP/HTTPS URLs. They have unique bundle IDs and are returned by `LSCopyAllHandlersForURLScheme`.

**Mitigation**: Common non-browser apps (VLC, IINA, MX Player, mpv) are hidden by default via `defaultHiddenBundleIDs`. Users can hide additional apps in Settings → Apps.

---

## 9. Hidden apps list uses bundle IDs, not display names

**Symptom**: Users must enter exact bundle IDs (e.g., `org.videolan.vlc`) to hide apps in Settings → Apps.

**Cause**: Display names are not guaranteed unique; bundle IDs are. The hidden set is stored as `Set<String>` of bundle IDs.

**UX note**: The Settings UI shows the bundle ID in monospace font. The "Show hidden" toggle in AddBrowserSheet reveals hidden apps for easy identification.

---

## 10. Onboarding activation policy timing

**Symptom**: Dock icon briefly appears and disappears during first launch.

**Cause**: Onboarding switches from `.accessory` to `.regular` activation policy to show its window, then back to `.accessory` when done. The Dock icon appears during the `.regular` phase.

**This is intentional**: The brief Dock appearance signals to the user that Chowser is running and provides a normal window interaction model during onboarding.

---

## 11. isHandlingURL timing (1.0s reset delay)

**Symptom**: Opening a URL and immediately interacting with the menu bar may be blocked for up to 1 second.

**Cause**: `isHandlingURL` is set to `true` when a URL arrives and reset after a 1.0s `DispatchQueue.main.asyncAfter` delay. This guards against `applicationShouldHandleReopen` race conditions.

**Impact**: Any code that checks `isHandlingURL` (e.g., to decide whether to show settings) will get a stale `true` for up to 1 second after the last URL event. This is the intended behavior — the 1.0s window ensures the URL handling pipeline completes.

---

## 12. Firefox profile ID semantics differ from Chromium

**Symptom**: Firefox `-P` flag expects the profile name, not the directory name.

**Cause**: Chromium uses `--profile-directory=<dir_name>` (e.g., "Profile 1"), which is the directory name under `Application Support/Google/Chrome/`. Firefox uses `-P <name>` where `<name>` is the `Name=` value from `profiles.ini`, which is the human-readable name (e.g., "default-release").

**Impact**: `BrowserProfile.id` stores the directory key for Chromium but the profile name for Firefox. The `launchInfo()` method handles this difference transparently.

**See**: `BrowserProfileDetector.swift` — Chromium uses JSON keys as IDs, Firefox uses INI `Name=` values.
