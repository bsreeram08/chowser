import Foundation
import Observation

/// Editing state for the Settings ▸ Rules page.
///
/// The store (`BrowserManager.routingRules`) only ever holds valid rules. What the user
/// is typing lives here as a *draft* until it validates, so an invalid edit is never
/// persisted and never thrown away:
/// - Editing a stored rule writes a draft, then commits it to the store whenever it
///   validates. While it's invalid the store keeps the last valid version and the
///   draft (plus its error) stays visible.
/// - A brand-new rule is a pending draft that isn't in the store at all until it
///   first validates; then it's inserted at its intended position.
/// Valid drafts are folded back into the store's normalized value when editing ends
/// (focus leaves a field or the selection moves), so the fields show what's saved.
@MainActor
@Observable
final class RulesEditorModel {
    typealias ValidationError = BrowserManager.RoutingRuleValidationError

    struct Row: Identifiable, Equatable {
        let id: UUID
        /// 1-based priority as shown in the table (includes unsaved rows).
        let position: Int
        /// What to display: the draft when one exists, otherwise the stored rule.
        let rule: BrowserRoutingRule
        let issue: ValidationError?
        /// True for a new rule that has never been saved.
        let isUnsaved: Bool
    }

    struct PendingNewRule: Equatable {
        var rule: BrowserRoutingRule
        /// Intended position in the store once it validates.
        var storeIndex: Int
    }

    struct TestOutcome: Equatable {
        enum Kind: Equatable {
            case empty
            case invalidURL
            case matched(rule: BrowserRoutingRule, browser: BrowserConfig, position: Int)
            case temporaryRoute(browser: BrowserConfig)
            case fallbackBrowser(BrowserConfig)
            case picker
        }

        var kind: Kind
        /// Human-readable notes about rules the router skipped, in priority order.
        var skipped: [String] = []

        var matchedRuleID: UUID? {
            if case .matched(let rule, _, _) = kind { return rule.id }
            return nil
        }
    }

    let manager: BrowserManager

    var selection: UUID? {
        didSet {
            guard oldValue != selection, let oldValue else { return }
            endEditing(oldValue)
        }
    }

    private(set) var drafts: [UUID: BrowserRoutingRule] = [:]
    private(set) var pendingNewRule: PendingNewRule?

    /// Set when the inspector should move keyboard focus to "Link matches" for a rule.
    var focusPatternRequest: UUID?

    /// Rule tester inputs, kept across popover openings.
    var testURL = ""
    var testSourceApp: String?

    init(manager: BrowserManager) {
        self.manager = manager
    }

    // MARK: Reading

    var rows: [Row] {
        var items: [(rule: BrowserRoutingRule, isDraft: Bool, isUnsaved: Bool)] = manager.routingRules.map { stored in
            if let draft = drafts[stored.id] {
                return (draft, true, false)
            }
            return (stored, false, false)
        }
        if let pending = pendingNewRule {
            items.insert((pending.rule, true, true), at: min(max(pending.storeIndex, 0), items.count))
        }
        return items.enumerated().map { offset, item in
            Row(
                id: item.rule.id,
                position: offset + 1,
                rule: item.rule,
                issue: item.isDraft ? validationError(for: item.rule) : nil,
                isUnsaved: item.isUnsaved
            )
        }
    }

    /// The value the inspector edits for `id`: the pending/draft value, or an editable
    /// copy of the stored rule. Nil when the rule no longer exists.
    func editableRule(for id: UUID) -> BrowserRoutingRule? {
        if let pending = pendingNewRule, pending.rule.id == id { return pending.rule }
        if let draft = drafts[id] { return draft }
        guard let stored = manager.routingRules.first(where: { $0.id == id }) else { return nil }
        return Self.editableCopy(of: stored)
    }

    func isUnsaved(_ id: UUID) -> Bool {
        pendingNewRule?.rule.id == id
    }

    /// True when the draft for `id` is invalid, so the store still holds an older version.
    func hasUnsavedInvalidEdits(_ id: UUID) -> Bool {
        guard let draft = drafts[id] else { return false }
        return validationError(for: draft) != nil
    }

    func validationError(for rule: BrowserRoutingRule) -> ValidationError? {
        if case .failure(let error) = manager.validateRoutingRule(rule) { return error }
        return nil
    }

    /// Stored rules get an auto-derived name equal to their host pattern when the name
    /// was left empty. Present that as an empty (optional) name so the name keeps
    /// following the pattern when the pattern is edited.
    static func editableCopy(of stored: BrowserRoutingRule) -> BrowserRoutingRule {
        var copy = stored
        if copy.name == copy.hostPattern { copy.name = "" }
        return copy
    }

    // MARK: Editing

    /// Applies an edit to the rule's draft and commits it to the store if it validates.
    func update(_ id: UUID, _ mutate: (inout BrowserRoutingRule) -> Void) {
        if var pending = pendingNewRule, pending.rule.id == id {
            mutate(&pending.rule)
            if case .success = manager.insertRoutingRule(pending.rule, at: pending.storeIndex) {
                pendingNewRule = nil
                // Keep showing exactly what was typed until editing ends.
                drafts[id] = pending.rule
            } else {
                pendingNewRule = pending
            }
            return
        }

        guard let stored = manager.routingRules.first(where: { $0.id == id }) else { return }
        var draft = drafts[id] ?? Self.editableCopy(of: stored)
        mutate(&draft)
        drafts[id] = draft
        if case .success(let normalized) = manager.validateRoutingRule(draft), normalized != stored {
            manager.updateRule(draft)
        }
    }

    /// Called when focus leaves a field or the selection moves off a rule. Valid drafts
    /// are dropped (the store already has them, normalized); invalid drafts are kept so
    /// nothing typed is lost. An untouched new rule is discarded when `discardBlank`
    /// is true (selection moved away) but kept while focus just moves between fields.
    func endEditing(_ id: UUID, discardBlank: Bool = true) {
        if let pending = pendingNewRule, pending.rule.id == id {
            if discardBlank && Self.isBlank(pending.rule) { pendingNewRule = nil }
            return
        }
        guard let draft = drafts[id] else { return }
        guard manager.routingRules.contains(where: { $0.id == id }) else {
            drafts[id] = nil
            return
        }
        if validationError(for: draft) == nil {
            drafts[id] = nil
        }
    }

    /// Throws away an invalid draft and goes back to the last saved version.
    func revert(_ id: UUID) {
        drafts[id] = nil
    }

    // MARK: Structural changes

    /// Adds a rule after the current selection (or at the end), selects it, and asks the
    /// inspector to focus "Link matches". If the prefilled values already validate, the
    /// rule is saved immediately; otherwise it stays a pending draft.
    func addRule(prefillHost: String? = nil, browserIdentity: String? = nil) {
        // Only one unsaved rule at a time: if one with typing in it exists, go back to it
        // instead of creating a second one (its text must never be lost).
        if let pending = pendingNewRule, !Self.isBlank(pending.rule) {
            selection = pending.rule.id
            focusPatternRequest = pending.rule.id
            return
        }
        if let pending = pendingNewRule {
            pendingNewRule = nil
            if selection == pending.rule.id { selection = nil }
        }

        let storeIndex = manager.routingRuleInsertionIndex(after: selection)
        let browser = browserIdentity.flatMap { identity in
            manager.configuredBrowsers.first(where: { $0.identity == identity })
        } ?? manager.configuredBrowsers.first

        let rule = BrowserRoutingRule(
            name: "",
            hostPattern: prefillHost ?? "",
            pathPrefix: nil,
            browserBundleId: browser?.bundleId ?? "",
            profile: browser?.profile
        )

        if prefillHost?.isEmpty == false, case .success = manager.insertRoutingRule(rule, at: storeIndex) {
            selection = rule.id
        } else {
            pendingNewRule = PendingNewRule(rule: rule, storeIndex: storeIndex)
            selection = rule.id
        }
        focusPatternRequest = rule.id
    }

    /// Deletes immediately (no confirmation). Stored rules get an undo that restores
    /// them at their original index. Selection moves to the next row, else the previous.
    func delete(_ id: UUID, undoManager: UndoManager?) {
        let before = rows
        guard let position = before.firstIndex(where: { $0.id == id }) else { return }
        let neighbor: UUID? = before.indices.contains(position + 1)
            ? before[position + 1].id
            : (position > 0 ? before[position - 1].id : nil)

        if let pending = pendingNewRule, pending.rule.id == id {
            pendingNewRule = nil
        } else {
            drafts[id] = nil
            manager.deleteRoutingRule(id: id, undoManager: undoManager)
        }

        if selection == id || selection == nil {
            selection = neighbor
        }
    }

    func setEnabled(_ id: UUID, _ isEnabled: Bool) {
        update(id) { $0.isEnabled = isEnabled }
        // A toggle from the table is a complete edit; fold it back unless the user is
        // in the middle of editing this rule in the inspector.
        if selection != id { endEditing(id) }
    }

    /// Reorders by table positions (`destination` is in pre-move coordinates, like
    /// `Array.move(fromOffsets:toOffset:)`). Stored rules move via
    /// `BrowserManager.moveRoutingRules`; an unsaved rule just changes its intended slot.
    func move(ids: [UUID], toDisplayIndex destination: Int) {
        let current = rows
        let clampedDestination = min(max(destination, 0), current.count)
        let movingSet = Set(ids)
        let storeDestination = current[..<clampedDestination].filter { !$0.isUnsaved }.count

        let offsets = IndexSet(ids.compactMap { id in manager.routingRules.firstIndex(where: { $0.id == id }) })
        if !offsets.isEmpty {
            manager.moveRoutingRules(from: offsets, to: storeDestination)
        }

        if var pending = pendingNewRule, movingSet.contains(pending.rule.id) {
            // Stored rows above the drop point that themselves moved don't count.
            let movedAbove = current[..<clampedDestination].filter { !$0.isUnsaved && movingSet.contains($0.id) }.count
            pending.storeIndex = storeDestination - movedAbove
            pendingNewRule = pending
        } else if var pending = pendingNewRule, !offsets.isEmpty {
            // Keep an unsaved row anchored to the stored rule it followed.
            let anchor = current.prefix { $0.id != pending.rule.id }.last { !$0.isUnsaved }?.id
            pending.storeIndex = manager.routingRuleInsertionIndex(after: anchor)
            if anchor == nil { pending.storeIndex = 0 }
            pendingNewRule = pending
        }
    }

    // MARK: Rule tester

    func testOutcome() -> TestOutcome {
        let trimmed = testURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return TestOutcome(kind: .empty) }
        guard let url = Self.parsedTestURL(trimmed) else { return TestOutcome(kind: .invalidURL) }

        let currentRows = rows
        let positionByID = Dictionary(uniqueKeysWithValues: currentRows.map { ($0.id, $0.position) })

        let kind: TestOutcome.Kind
        if let route = manager.resolvedRoute(for: url, sourceApp: testSourceApp ?? "") {
            if let rule = route.rule {
                kind = .matched(rule: rule, browser: route.browser, position: positionByID[rule.id] ?? 0)
            } else {
                kind = .temporaryRoute(browser: route.browser)
            }
        } else if let fallback = manager.fallbackRoute() {
            kind = .fallbackBrowser(fallback.browser)
        } else {
            kind = .picker
        }

        var cutoff = Int.max
        if case .matched(_, _, let position) = kind { cutoff = position }

        var notes: [(position: Int, text: String)] = []
        for issue in manager.routingRuleIssues() {
            guard let position = positionByID[issue.rule.id], position < cutoff else { continue }
            notes.append((position, "Skipped rule \(position): \(RoutingRuleMessages.skipReason(for: issue.error))"))
        }
        for row in currentRows where row.position < cutoff && row.issue != nil && row.rule.isEnabled {
            if row.isUnsaved {
                notes.append((row.position, "Rule \(row.position) isn’t saved yet because it has an error."))
            } else if !notes.contains(where: { $0.position == row.position }) {
                notes.append((row.position, "Rule \(row.position) has an unsaved edit with an error; its last saved version was tested."))
            }
        }

        return TestOutcome(kind: kind, skipped: notes.sorted { $0.position < $1.position }.map(\.text))
    }

    static func parsedTestURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    // MARK: Helpers

    static func isBlank(_ rule: BrowserRoutingRule) -> Bool {
        rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rule.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (rule.pathPrefix ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rule.sourceAppBundleIDs.isEmpty
    }
}

/// Which inspector field a validation error belongs under.
enum RuleEditorField: Hashable {
    case name
    case pattern
    case path
    case sourceApps
    case browser
}

/// User-facing copy for routing-rule validation. Pattern errors are refined from the raw
/// text so the message says what's actually wrong ("has two dots in a row") instead of a
/// generic "invalid".
enum RoutingRuleMessages {
    typealias ValidationError = BrowserManager.RoutingRuleValidationError

    nonisolated static func field(for error: ValidationError) -> RuleEditorField? {
        switch error {
        case .invalidHostPattern, .invalidRegexPattern, .regexTooComplex: return .pattern
        case .invalidPathPrefix: return .path
        case .invalidSourceAppBundleId: return .sourceApps
        case .browserNotFound: return .browser
        case .ruleNotFound: return nil
        }
    }

    static func message(for error: ValidationError, rule: BrowserRoutingRule) -> String {
        switch error {
        case .invalidHostPattern:
            return hostPatternMessage(rule.hostPattern)
        case .invalidRegexPattern:
            if rule.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Enter a regular expression to match, like ^(www\\.)?github\\.com$."
            }
            if rule.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).count > 500 {
                return "This regular expression is too long. Keep it under 500 characters."
            }
            return "This regular expression isn’t valid. Check for unbalanced brackets or parentheses."
        case .regexTooComplex:
            return "This pattern could make link opening very slow. Simplify nested repeats like (a+)+."
        case .invalidPathPrefix:
            return "A path can’t contain spaces or a full link. Use something like /docs."
        case .invalidSourceAppBundleId:
            return "One of these apps has an invalid bundle identifier. Remove it and add it again."
        case .browserNotFound:
            return "This browser isn’t in your browser list anymore. Choose another one."
        case .ruleNotFound:
            return "This rule no longer exists."
        }
    }

    static func skipReason(for error: ValidationError) -> String {
        switch error {
        case .browserNotFound: return "its browser is missing."
        case .invalidHostPattern, .invalidRegexPattern, .regexTooComplex: return "its link pattern has an error."
        case .invalidPathPrefix: return "its path has an error."
        case .invalidSourceAppBundleId: return "one of its apps is invalid."
        case .ruleNotFound: return "it no longer exists."
        }
    }

    /// Mirrors the checks in `BrowserManager.isValidHostPattern` to explain a failure.
    static func hostPatternMessage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter a link to match, like github.com." }

        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.contains(where: \.isEmpty) && parts.count > 1 {
            return "There’s an empty entry between commas."
        }

        for part in parts {
            if part.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                return "Links can’t contain spaces. Separate several domains with commas."
            }
            var host = part.lowercased()
            if let scheme = host.range(of: "://") { host = String(host[scheme.upperBound...]) }
            if let slash = host.firstIndex(of: "/") { host = String(host[..<slash]) }
            if let colon = host.firstIndex(of: ":") { host = String(host[..<colon]) }
            guard !host.isEmpty else { return "Start with a domain, like github.com." }
            if host == "*" { continue }
            if host.contains("..") { return "“\(host)” has two dots in a row." }
            if host.hasPrefix(".") { return "A domain can’t start with a dot." }
            if host.contains("*") && !(host.hasPrefix("*.") && !host.dropFirst(2).contains("*")) {
                return "Use * only at the start, like *.slack.com."
            }
            let bare = host.hasPrefix("*.") ? String(host.dropFirst(2)) : host
            let labels = bare.split(separator: ".", omittingEmptySubsequences: false)
            if labels.contains(where: { $0.hasPrefix("-") || $0.hasSuffix("-") }) {
                return "A part of a domain can’t start or end with a hyphen."
            }
            if bare.contains(where: { !($0.isLetter || $0.isNumber || $0 == "-" || $0 == ".") }) {
                return "That doesn’t look like a domain. Try something like github.com."
            }
        }
        return "That doesn’t look like a domain. Try something like github.com."
    }

    /// A path typed into "Link matches" is ignored by the matcher (only the host is
    /// compared). Returns that path so the editor can point it out instead of letting it
    /// vanish silently on save.
    static func ignoredPathInPattern(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(",") else { return nil }
        var rest = trimmed
        if let scheme = rest.range(of: "://") { rest = String(rest[scheme.upperBound...]) }
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        let path = String(rest[slash...])
        guard path != "/" else { return nil }
        return path.hasSuffix("*") ? String(path.dropLast()) : path
    }
}
