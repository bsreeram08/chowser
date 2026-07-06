import SwiftUI
import Foundation

/// One-time review sheet for migration-time merge suggestions (Phase 2). Never applies
/// a merge silently — every suggestion needs an explicit Merge or Reject, or Accept All.
struct RuleMergeReviewSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if manager.pendingRuleMergeSuggestions.isEmpty {
                SettingsEmptyContent(
                    systemImage: "checkmark.circle",
                    title: "All done",
                    message: "No more suggested merges."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(manager.pendingRuleMergeSuggestions) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            footer
        }
        .frame(width: 520, height: 480)
        .accessibilityIdentifier("settings.ruleMergeReview.root")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Merge similar rules?")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text("These rules only differ by source app and route to the same browser. Merge them into one rule?")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func suggestionRow(_ suggestion: RuleMergeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.mergedName)
                    .font(.system(size: 13, weight: .semibold))
                Text(suggestion.hostPattern)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(suggestion.mergedSourceAppBundleIDs, id: \.self) { bundleId in
                    AppBadgeView(bundleId: bundleId, fallbackText: bundleId)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                AppBadgeView(bundleId: suggestion.browserBundleId, fallbackText: suggestion.browserBundleId)
            }

            HStack {
                Button("Reject") {
                    manager.rejectRuleMergeSuggestion(suggestion)
                }
                .controlSize(.small)
                .accessibilityIdentifier("settings.ruleMergeReview.rejectButton")

                Spacer()

                Button("Merge") {
                    manager.acceptRuleMergeSuggestion(suggestion)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("settings.ruleMergeReview.mergeButton")
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("settings.ruleMergeReview.suggestionRow")
    }

    private var footer: some View {
        HStack {
            Button("Accept All") {
                manager.acceptAllPendingRuleMergeSuggestions()
            }
            .disabled(manager.pendingRuleMergeSuggestions.isEmpty)
            .accessibilityIdentifier("settings.ruleMergeReview.acceptAllButton")

            Spacer()

            Button("Done") {
                manager.finishRuleMergeReview()
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("settings.ruleMergeReview.doneButton")
        }
        .padding(16)
    }
}
