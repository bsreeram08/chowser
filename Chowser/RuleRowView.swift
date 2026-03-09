import SwiftUI
import Foundation
import AppKit

struct RuleRowView: View {
    let rule: BrowserRoutingRule
    let browser: BrowserConfig?
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(rule.isEnabled ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                if rule.isEnabled {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 4)
                        .frame(width: 12, height: 12)
                }
            }
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rule.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    if rule.useRegex {
                        Text("REGEX")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                
                Text(rule.hostPattern)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Browser Icon
            if let browser = browser, let icon = AppMetadataCache.shared.icon(for: browser.bundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
    }
}
