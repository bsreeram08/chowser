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

// MARK: - App Metadata Helper

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
                .accessibilityIdentifier("settings.rule.sourceApp.addButton")
            }
        }
    }

    private func chip(for bundleId: String) -> some View {
        HStack(spacing: 4) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .frame(width: 12, height: 12)
                Text((Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? bundleId)
                    .font(.system(size: 11, weight: .medium))
            } else {
                Text(bundleId)
                    .font(.system(size: 11, weight: .medium))
            }

            Button(action: { remove(bundleId) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
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
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleId = Bundle(url: url)?.bundleIdentifier,
              !bundleIDs.contains(bundleId) else { return }
        bundleIDs.append(bundleId)
        onCommit()
    }
}

struct AppBadgeView: View {
    let bundleId: String?
    let fallbackText: String
    
    var body: some View {
        HStack(spacing: 6) {
            if let bundleId = bundleId, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .frame(width: 14, height: 14)
                let name = (Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? bundleId
                Text(name)
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
