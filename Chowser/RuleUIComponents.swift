import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Shared Rule UI Components

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.accent)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            content
                .padding(16)
                .customCardSurface(cornerRadius: 12)
        }
    }
}

struct DetailRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            content
        }
    }
}

// MARK: - App Metadata Helpers

/// Cached display name for an app bundle ID (falls back to the bundle ID itself).
@MainActor
func appDisplayName(forBundleID bundleId: String) -> String {
    AppMetadataCache.shared.displayName(for: bundleId) ?? bundleId
}

/// Small app icon backed by `AppMetadataCache`, with a monochrome placeholder when the
/// app isn't installed.
struct CachedAppIcon: View {
    let bundleId: String
    var size: CGFloat = 16

    var body: some View {
        if let icon = AppMetadataCache.shared.icon(for: bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// Lets the user pick an application bundle from disk; returns its bundle ID.
@MainActor
func chooseApplicationBundleID() -> String? {
    let panel = NSOpenPanel()
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.applicationBundle]
    panel.prompt = "Choose"
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return Bundle(url: url)?.bundleIdentifier
}

/// Chip row for a routing rule's source-app condition (Phase 2, FR-010/011). Zero
/// chips renders as a single non-removable "Any source app" ghost chip so an empty
/// list can't be mistaken for an unsaved/broken state (design review fix).
struct SourceAppChipsView: View {
    @Binding var bundleIDs: [String]
    var onCommit: () -> Void = {}

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if bundleIDs.isEmpty {
                    Text("Any source app")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                        .accessibilityIdentifier("settings.rule.sourceApp.anyChip")
                } else {
                    ForEach(bundleIDs, id: \.self) { bundleId in
                        chip(for: bundleId)
                    }
                }

                Button(action: addSourceApp) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Add Source App")
                .accessibilityIdentifier("settings.rule.sourceApp.addButton")
            }
        }
    }

    private func chip(for bundleId: String) -> some View {
        HStack(spacing: 4) {
            if AppMetadataCache.shared.appURL(for: bundleId) != nil {
                CachedAppIcon(bundleId: bundleId, size: 12)
            }
            Text(appDisplayName(forBundleID: bundleId))
                .font(.system(size: 11, weight: .medium))

            Button(action: { remove(bundleId) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Remove \(appDisplayName(forBundleID: bundleId))")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .accessibilityIdentifier("settings.rule.sourceApp.chip")
    }

    private func remove(_ bundleId: String) {
        bundleIDs.removeAll { $0 == bundleId }
        onCommit()
    }

    private func addSourceApp() {
        guard let bundleId = chooseApplicationBundleID(), !bundleIDs.contains(bundleId) else { return }
        bundleIDs.append(bundleId)
        onCommit()
    }
}

struct AppBadgeView: View {
    let bundleId: String?
    let fallbackText: String

    var body: some View {
        HStack(spacing: 6) {
            if let bundleId, AppMetadataCache.shared.appURL(for: bundleId) != nil {
                CachedAppIcon(bundleId: bundleId, size: 14)
                Text(appDisplayName(forBundleID: bundleId))
                    .font(.system(size: 12, weight: .medium))
            } else {
                Text(fallbackText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Flow layout

/// Left-to-right wrapping layout for token lists.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Source app tokens (Rules inspector)

/// Token-style "From app" editor: one token per app with a remove button, plus an
/// "Add App" menu offering running apps and a file chooser. Empty means any app.
struct SourceAppTokenList: View {
    let bundleIDs: [String]
    let onChange: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout {
                if bundleIDs.isEmpty {
                    Text("Any app")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 3)
                        .accessibilityIdentifier("settings.rule.sourceApp.anyChip")
                }
                ForEach(bundleIDs, id: \.self) { bundleId in
                    token(for: bundleId)
                }
                addMenu
            }
        }
    }

    private func token(for bundleId: String) -> some View {
        let name = appDisplayName(forBundleID: bundleId)
        return HStack(spacing: 4) {
            CachedAppIcon(bundleId: bundleId, size: 14)
            Text(name)
                .lineLimit(1)
            Button {
                onChange(bundleIDs.filter { $0 != bundleId })
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(name)")
            .help("Remove \(name)")
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
        .help(bundleId)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.rule.sourceApp.chip")
    }

    private var addMenu: some View {
        Menu {
            let candidates = runningAppCandidates
            if !candidates.isEmpty {
                Section("Running Apps") {
                    ForEach(candidates, id: \.bundleId) { app in
                        Button(app.name) { add(app.bundleId) }
                    }
                }
            }
            Button("Choose Application…") {
                if let bundleId = chooseApplicationBundleID() { add(bundleId) }
            }
        } label: {
            Label("Add App", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityIdentifier("settings.rule.sourceApp.addButton")
    }

    private var runningAppCandidates: [(name: String, bundleId: String)] {
        let ownID = Bundle.main.bundleIdentifier
        var seen = Set(bundleIDs)
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (name: String, bundleId: String)? in
                guard let id = app.bundleIdentifier, id != ownID, seen.insert(id).inserted else { return nil }
                return (app.localizedName ?? id, id)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func add(_ bundleId: String) {
        guard !bundleIDs.contains(bundleId) else { return }
        onChange(bundleIDs + [bundleId])
    }
}

// MARK: - Rule tester popover

/// "Test a link" popover: a URL, the app it was clicked in, and a live result computed
/// with `BrowserManager.resolvedRoute(for:sourceApp:)` plus the fallback policy.
struct RuleTesterPopover: View {
    @Bindable var model: RulesEditorModel
    let sourceAppOptions: [String]
    @FocusState private var urlFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test a Link")
                .font(.headline)

            TextField("Link", text: $model.testURL, prompt: Text("https://github.com/acme"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .focused($urlFocused)
                .accessibilityLabel("Link to test")
                .accessibilityIdentifier("settings.ruleTester.urlField")

            Picker("Clicked in", selection: $model.testSourceApp) {
                Text("Any app").tag(String?.none)
                if !sourceAppOptions.isEmpty {
                    Divider()
                    ForEach(sourceAppOptions, id: \.self) { bundleId in
                        Text(appDisplayName(forBundleID: bundleId)).tag(Optional(bundleId))
                    }
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings.ruleTester.sourceAppPicker")

            Divider()

            result
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.ruleTester.result")
        }
        .padding(16)
        .frame(width: 340)
        .accessibilityIdentifier("settings.ruleTester.popover")
        .onAppear { urlFocused = true }
    }

    @ViewBuilder
    private var result: some View {
        let outcome = model.testOutcome()
        VStack(alignment: .leading, spacing: 6) {
            switch outcome.kind {
            case .empty:
                Text("Paste or type a link to see where it would open.")
                    .foregroundStyle(.secondary)
            case .invalidURL:
                Label("That isn’t a complete link. Try https://github.com/acme.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .matched(let rule, let browser, let position):
                destination(browser, privately: rule.usePrivateMode)
                Text(matchedCaption(rule: rule, position: position))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .temporaryRoute(let browser):
                destination(browser, privately: false)
                Text("Focus Mode is on, so rules are bypassed until it ends.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .fallbackBrowser(let browser):
                destination(browser, privately: false)
                Text("No rule matches this link, so the fallback browser is used.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .picker:
                Label("Shows the picker", systemImage: "square.grid.2x2")
                Text("No rule matches this link.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(outcome.skipped, id: \.self) { note in
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func destination(_ browser: BrowserConfig, privately: Bool) -> some View {
        HStack(spacing: 6) {
            Text("Opens in")
            CachedAppIcon(bundleId: browser.bundleId, size: 16)
            Text(browser.profileQualifiedName)
                .fontWeight(.semibold)
            if privately {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("privately")
            }
        }
    }

    private func matchedCaption(rule: BrowserRoutingRule, position: Int) -> String {
        let label = rule.name.isEmpty ? rule.hostPattern : rule.name
        if position > 1 {
            return "Matched rule \(position): \(label). Rules 1–\(position - 1) were checked first."
        }
        return "Matched rule \(position): \(label)."
    }
}

extension BrowserConfig {
    /// "Chrome (Work)" when a profile is set, otherwise just the name.
    var profileQualifiedName: String {
        if let profile, !profile.isEmpty { return "\(name) (\(profile))" }
        return name
    }
}
