import SwiftUI
import Foundation
import AppKit

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
