import SwiftUI
import AppKit

/// The radial ring's usable angular range in SwiftUI coordinates (0 points right and
/// positive angles point down). A constrained range faces inward from a screen edge.
struct RadialPickerShape: Equatable {
    let centerAngle: CGFloat
    let span: CGFloat

    static let circle = RadialPickerShape(centerAngle: -.pi / 2, span: .pi * 2)
}

/// Pure geometry shared by the radial view, AppKit window placement, and unit tests.
enum RadialPickerGeometry {
    static let outerRadius: CGFloat = 160
    static let innerRadius: CGFloat = 43
    static let itemRadius: CGFloat = 108
    static let deadZoneRadius: CGFloat = 38
    static let entrySize = CGSize(width: 56, height: 56)

    static func shape(anchor: CGPoint, visibleFrame: CGRect, requiredRadius: CGFloat = outerRadius + 12) -> RadialPickerShape {
        let nearLeft = anchor.x - visibleFrame.minX < requiredRadius
        let nearRight = visibleFrame.maxX - anchor.x < requiredRadius
        let nearBottom = anchor.y - visibleFrame.minY < requiredRadius
        let nearTop = visibleFrame.maxY - anchor.y < requiredRadius
        let constrainedCount = [nearLeft, nearRight, nearBottom, nearTop].filter { $0 }.count

        if constrainedCount >= 2 {
            switch (nearLeft, nearRight, nearBottom, nearTop) {
            case (true, _, _, true): return RadialPickerShape(centerAngle: .pi / 4, span: .pi * 0.68)
            case (_, true, _, true): return RadialPickerShape(centerAngle: .pi * 3 / 4, span: .pi * 0.68)
            case (true, _, true, _): return RadialPickerShape(centerAngle: -.pi / 4, span: .pi * 0.68)
            case (_, true, true, _): return RadialPickerShape(centerAngle: -.pi * 3 / 4, span: .pi * 0.68)
            default: break
            }
        }

        if nearLeft { return RadialPickerShape(centerAngle: 0, span: .pi) }
        if nearRight { return RadialPickerShape(centerAngle: .pi, span: .pi) }
        if nearTop { return RadialPickerShape(centerAngle: .pi / 2, span: .pi) }
        if nearBottom { return RadialPickerShape(centerAngle: -.pi / 2, span: .pi) }
        return .circle
    }

    static func centerAngles(itemCount: Int, shape: RadialPickerShape) -> [CGFloat] {
        guard itemCount > 0 else { return [] }
        let step = shape.span / CGFloat(itemCount)
        if shape.span >= .pi * 2 - 0.001 {
            // Browser shortcut 1 starts at twelve o'clock; configured order proceeds clockwise.
            return (0..<itemCount).map { -.pi / 2 + step * CGFloat($0) }
        }
        let start = shape.centerAngle - shape.span / 2
        return (0..<itemCount).map { start + step * (CGFloat($0) + 0.5) }
    }

    static func entryCenters(
        itemCount: Int,
        shape: RadialPickerShape,
        center: CGPoint,
        panelBounds: CGRect,
        inset: CGFloat = 12
    ) -> [CGPoint] {
        let angles = centerAngles(itemCount: itemCount, shape: shape)
        guard !angles.isEmpty else { return [] }
        if shape.span >= .pi * 2 - 0.001 {
            return angles.map {
                CGPoint(x: center.x + cos($0) * itemRadius, y: center.y + sin($0) * itemRadius)
            }
        }

        let usableBounds = panelBounds.insetBy(dx: inset, dy: inset)
        let candidateRadii: [CGFloat] = [60, 90, 120, 150, 180]
        var centers: [CGPoint] = []
        var frames: [CGRect] = []

        func placeEntry(_ index: Int) -> Bool {
            guard index < angles.count else { return true }
            for radius in candidateRadii {
                let candidate = CGPoint(
                    x: center.x + cos(angles[index]) * radius,
                    y: center.y + sin(angles[index]) * radius
                )
                let frame = CGRect(
                    x: candidate.x - entrySize.width / 2,
                    y: candidate.y - entrySize.height / 2,
                    width: entrySize.width,
                    height: entrySize.height
                )
                guard usableBounds.contains(frame), !frames.contains(where: { $0.intersects(frame) }) else { continue }
                centers.append(candidate)
                frames.append(frame)
                if placeEntry(index + 1) { return true }
                centers.removeLast()
                frames.removeLast()
            }
            return false
        }

        if placeEntry(0) { return centers }
        return angles.map {
            CGPoint(x: center.x + cos($0) * itemRadius, y: center.y + sin($0) * itemRadius)
        }
    }

    static func selectedIndex(
        at location: CGPoint,
        center: CGPoint,
        itemCount: Int,
        shape: RadialPickerShape,
        deadZone: CGFloat = deadZoneRadius
    ) -> Int? {
        guard itemCount > 0 else { return nil }
        let delta = CGPoint(x: location.x - center.x, y: location.y - center.y)
        guard hypot(delta.x, delta.y) >= deadZone else { return nil }
        let angle = atan2(delta.y, delta.x)
        if shape.span < .pi * 2 - 0.001,
           angularDistance(angle, shape.centerAngle) > shape.span / 2 {
            return nil
        }

        return centerAngles(itemCount: itemCount, shape: shape)
            .enumerated()
            .min(by: { angularDistance(angle, $0.element) < angularDistance(angle, $1.element) })?
            .offset
    }

    static func wedgePath(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat
    ) -> Path {
        var path = Path()
        let samples = 18
        for sample in 0...samples {
            let progress = CGFloat(sample) / CGFloat(samples)
            let angle = startAngle + (endAngle - startAngle) * progress
            let point = CGPoint(x: center.x + cos(angle) * outerRadius, y: center.y + sin(angle) * outerRadius)
            if sample == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for sample in (0...samples).reversed() {
            let progress = CGFloat(sample) / CGFloat(samples)
            let angle = startAngle + (endAngle - startAngle) * progress
            path.addLine(to: CGPoint(x: center.x + cos(angle) * innerRadius, y: center.y + sin(angle) * innerRadius))
        }
        path.closeSubpath()
        return path
    }

    private static func angularDistance(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        var difference = (lhs - rhs).truncatingRemainder(dividingBy: .pi * 2)
        if difference > .pi { difference -= .pi * 2 }
        if difference < -.pi { difference += .pi * 2 }
        return abs(difference)
    }
}

struct QuickPickerOverflowPlacement: Equatable {
    let offset: CGSize
    let anchor: UnitPoint

    static func radial(
        moreAngle: CGFloat,
        panelSize: CGFloat = 500,
        listSize: CGSize = CGSize(width: 220, height: 282),
        inset: CGFloat = 12,
        distance: CGFloat = 130
    ) -> QuickPickerOverflowPlacement {
        let direction = CGVector(dx: cos(moreAngle), dy: sin(moreAngle))
        let maximumX = max(0, panelSize / 2 - listSize.width / 2 - inset)
        let maximumY = max(0, panelSize / 2 - listSize.height / 2 - inset)
        let offset = CGSize(
            width: min(max(direction.dx * distance, -maximumX), maximumX),
            height: min(max(direction.dy * distance, -maximumY), maximumY)
        )
        let anchor = UnitPoint(
            x: min(max(0.5 - direction.dx * 0.5, 0), 1),
            y: min(max(0.5 - direction.dy * 0.5, 0), 1)
        )
        return QuickPickerOverflowPlacement(offset: offset, anchor: anchor)
    }
}

struct RadialPickerSelectionState: Equatable {
    private(set) var index: Int?

    init(index: Int? = nil) {
        self.index = index
    }

    mutating func update(
        at location: CGPoint,
        center: CGPoint,
        itemCount: Int,
        shape: RadialPickerShape,
        deadZone: CGFloat = RadialPickerGeometry.deadZoneRadius
    ) {
        index = RadialPickerGeometry.selectedIndex(
            at: location,
            center: center,
            itemCount: itemCount,
            shape: shape,
            deadZone: deadZone
        )
    }
}

private struct QuickPickerEntry: Identifiable {
    let id: String
    let browser: BrowserConfig?

    var isMore: Bool { browser == nil }
}

struct PickerActivationGuard: Equatable {
    private(set) var isActive = false

    mutating func begin() -> Bool {
        guard !isActive else { return false }
        isActive = true
        return true
    }

    mutating func reset() {
        isActive = false
    }
}

enum MinimalPickerGeometry {
    static func selectedIndex(
        at x: CGFloat,
        entryCount: Int,
        leadingInset: CGFloat = 7,
        entryWidth: CGFloat = 43
    ) -> Int? {
        guard entryCount > 0 else { return nil }
        let localX = x - leadingInset
        guard localX >= 0, localX < CGFloat(entryCount) * entryWidth else { return nil }
        return min(entryCount - 1, max(0, Int(localX / entryWidth)))
    }
}

struct RadialPickerView: View {
    let browsers: [BrowserConfig]
    let shape: RadialPickerShape
    @Binding var selectedBrowserID: UUID?
    @Binding var moreSelected: Bool
    @Binding var overflowPresented: Bool
    @Binding var overflowSelectedBrowserID: UUID?
    let privateMode: Bool
    let openBrowser: (BrowserConfig) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var activationGuard = PickerActivationGuard()

    // Extra transparent room keeps the expanded More list inside the borderless panel
    // even when the directional orbit is centered on a cursor at a screen edge.
    private let size: CGFloat = 500

    private var directBrowsers: [BrowserConfig] { Array(browsers.prefix(8)) }
    private var overflowBrowsers: [BrowserConfig] { Array(browsers.dropFirst(8)) }
    private var entries: [QuickPickerEntry] {
        var result = directBrowsers.map { QuickPickerEntry(id: $0.id.uuidString, browser: $0) }
        if !overflowBrowsers.isEmpty { result.append(QuickPickerEntry(id: "more", browser: nil)) }
        return result
    }
    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }

    var body: some View {
        ZStack {
            directionalOrbit
                .opacity(overflowPresented ? 0.18 : 1)
                .blur(radius: overflowPresented && !reduceMotion ? 2 : 0)

            if privateMode && !overflowPresented {
                Label("Private", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                            .stroke(Color.purple.opacity(contrast == .increased ? 0.9 : 0.5), lineWidth: contrast == .increased ? 2 : 1)
                    )
                    .position(center)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("picker.privateModeIndicator")
            }

            if overflowPresented {
                QuickPickerOverflowList(
                    browsers: overflowBrowsers,
                    selectedBrowserID: $overflowSelectedBrowserID,
                    privateMode: privateMode,
                    close: { overflowPresented = false },
                    openBrowser: openBrowser
                )
                .offset(overflowPlacement.offset)
                .transition(PickerMotion.transition(
                    reduceMotion: reduceMotion,
                    scale: 0.96,
                    anchor: overflowPlacement.anchor
                ))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("picker.radial")
        .onContinuousHover(coordinateSpace: .local) { phase in
            guard !overflowPresented else { return }
            if case let .active(location) = phase { updateSelection(at: location) }
        }
        .onTapGesture {
            guard !overflowPresented else { return }
            activateSelection()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .local)
                .onChanged { value in
                    guard !overflowPresented else { return }
                    updateSelection(at: value.location)
                }
                .onEnded { value in
                    guard !overflowPresented else { return }
                    updateSelection(at: value.location)
                    activateSelection()
                }
        )
        .animation(PickerMotion.occasional(reduceMotion: reduceMotion), value: overflowPresented)
    }

    private var directionalOrbit: some View {
        let angles = RadialPickerGeometry.centerAngles(itemCount: entries.count, shape: shape)
        let entryCenters = RadialPickerGeometry.entryCenters(
            itemCount: entries.count,
            shape: shape,
            center: center,
            panelBounds: CGRect(x: 0, y: 0, width: size, height: size)
        )
        let step = entries.isEmpty ? 0 : shape.span / CGFloat(entries.count)
        let gap: CGFloat = shape.span >= .pi * 2 - 0.001 ? 0.025 : 0.04
        let wedgeOuterRadius = shape.span >= .pi * 2 - 0.001 ? RadialPickerGeometry.outerRadius : 210

        return ZStack {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                let isSelected = selectionIndex == index
                let wedge = RadialPickerGeometry.wedgePath(
                    center: center,
                    innerRadius: RadialPickerGeometry.innerRadius,
                    outerRadius: wedgeOuterRadius,
                    startAngle: angles[index] - step / 2 + gap,
                    endAngle: angles[index] + step / 2 - gap
                )

                if isSelected {
                    wedge
                        .fill(privateMode ? Color.purple.opacity(0.24) : Color.pickerAccent.opacity(0.2))
                        .overlay(
                            wedge.stroke(
                                privateMode ? Color.purple.opacity(0.9) : Color.pickerAccent.opacity(0.9),
                                lineWidth: contrast == .increased ? 2 : 1.5
                            )
                        )
                        .transition(.opacity)
                }

                Button {
                    select(index: index)
                    activateSelection()
                } label: {
                    radialEntry(entry, selected: isSelected)
                }
                .buttonStyle(PickerPressButtonStyle())
                .contentShape(Rectangle())
                .position(entryCenters[index])
                .accessibilityLabel(accessibilityLabel(for: entry))
                .accessibilityValue(accessibilityValue(isSelected: isSelected))
            }
        }
    }

    @ViewBuilder
    private func radialEntry(_ entry: QuickPickerEntry, selected: Bool) -> some View {
        VStack(spacing: 1) {
            if let browser = entry.browser {
                QuickBrowserIcon(browser: browser, size: 26)
            } else {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }

            VStack(spacing: 0) {
                Text(entry.browser.map(quickBrowserName) ?? "More")
                    .font(.system(size: 11, weight: selected ? .bold : .semibold))
                if let browser = entry.browser, let profile = quickProfileName(browser) {
                    Text(profile).font(.system(size: 10)).foregroundStyle(.secondary)
                } else if entry.isMore {
                    Text("\(overflowBrowsers.count) more").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .frame(width: 50)
        }
        .frame(width: RadialPickerGeometry.entrySize.width, height: RadialPickerGeometry.entrySize.height)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(selected ? 0.96 : 0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            selected
                                ? (privateMode ? Color.purple.opacity(0.9) : Color.pickerAccent.opacity(0.9))
                                : Color.primary.opacity(0.12),
                            lineWidth: selected ? (contrast == .increased ? 2 : 1.5) : 0.8
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 7, y: 3)
        )
        .overlay(alignment: .topTrailing) {
            if selected && differentiateWithoutColor {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(3)
            }
        }
    }

    private var overflowPlacement: QuickPickerOverflowPlacement {
        let angles = RadialPickerGeometry.centerAngles(itemCount: entries.count, shape: shape)
        guard !overflowBrowsers.isEmpty, angles.indices.contains(directBrowsers.count) else {
            return QuickPickerOverflowPlacement(offset: .zero, anchor: .center)
        }
        return .radial(moreAngle: angles[directBrowsers.count])
    }

    private var selectionIndex: Int? {
        if moreSelected, !overflowBrowsers.isEmpty { return directBrowsers.count }
        guard let selectedBrowserID else { return nil }
        return directBrowsers.firstIndex(where: { $0.id == selectedBrowserID })
    }

    private func updateSelection(at location: CGPoint) {
        var state = RadialPickerSelectionState(index: selectionIndex)
        state.update(
            at: location,
            center: center,
            itemCount: entries.count,
            shape: shape
        )
        guard let index = state.index else {
            selectedBrowserID = nil
            moreSelected = false
            return
        }
        select(index: index)
    }

    private func select(index: Int) {
        guard entries.indices.contains(index) else { return }
        if let browser = entries[index].browser {
            selectedBrowserID = browser.id
            moreSelected = false
        } else {
            selectedBrowserID = nil
            moreSelected = true
        }
    }

    private func activateSelection() {
        if moreSelected, !overflowBrowsers.isEmpty {
            guard activationGuard.begin() else { return }
            overflowSelectedBrowserID = overflowBrowsers.first?.id
            overflowPresented = true
        } else if let selectedBrowserID,
                  let browser = directBrowsers.first(where: { $0.id == selectedBrowserID }) {
            guard activationGuard.begin() else { return }
            openBrowser(browser)
        } else {
            return
        }
        DispatchQueue.main.async { activationGuard.reset() }
    }

    private func accessibilityLabel(for entry: QuickPickerEntry) -> String {
        guard let browser = entry.browser else { return "More browsers and profiles" }
        return quickPickerAccessibilityLabel(browser, privateMode: privateMode)
    }

    private func accessibilityValue(isSelected: Bool) -> String {
        quickPickerAccessibilityValue(isSelected: isSelected, privateMode: privateMode)
    }
}

struct MinimalPickerView: View {
    let browsers: [BrowserConfig]
    @Binding var selectedBrowserID: UUID?
    @Binding var moreSelected: Bool
    @Binding var overflowPresented: Bool
    @Binding var overflowSelectedBrowserID: UUID?
    let privateMode: Bool
    let openBrowser: (BrowserConfig) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var activationGuard = PickerActivationGuard()

    private var directBrowsers: [BrowserConfig] { Array(browsers.prefix(8)) }
    private var overflowBrowsers: [BrowserConfig] { Array(browsers.dropFirst(8)) }
    private var entryCount: Int { directBrowsers.count + (overflowBrowsers.isEmpty ? 0 : 1) }
    private var stripWidth: CGFloat { CGFloat(entryCount) * 43 + 14 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    if privateMode {
                        Image(systemName: "lock.fill")
                    }
                    Text(selectionCaption)
                }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(height: 16)
                    .accessibilityIdentifier(privateMode ? "picker.privateModeIndicator" : "picker.selectionCaption")

                HStack(spacing: 3) {
                    ForEach(directBrowsers) { browser in
                        minimalEntry(browser: browser)
                    }
                    if !overflowBrowsers.isEmpty { moreEntry }
                }
            }
            .padding(7)
            .frame(width: stripWidth)
            .pickerPanelSurface()

            if overflowPresented {
                QuickPickerOverflowList(
                    browsers: overflowBrowsers,
                    selectedBrowserID: $overflowSelectedBrowserID,
                    privateMode: privateMode,
                    close: { overflowPresented = false },
                    openBrowser: openBrowser
                )
                .padding(.top, 6)
                .transition(PickerMotion.transition(
                    reduceMotion: reduceMotion,
                    scale: 0.96,
                    anchor: .topTrailing
                ))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("picker.minimal")
        .simultaneousGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .local)
                .onChanged { value in
                    guard !overflowPresented else { return }
                    updateSelection(x: value.location.x)
                }
                .onEnded { value in
                    guard !overflowPresented else { return }
                    updateSelection(x: value.location.x)
                    activateSelection()
                }
        )
        .animation(PickerMotion.occasional(reduceMotion: reduceMotion), value: overflowPresented)
    }

    private func minimalEntry(browser: BrowserConfig) -> some View {
        let selected = !moreSelected && selectedBrowserID == browser.id
        return Button {
            selectedBrowserID = browser.id
            moreSelected = false
            activateSelection()
        } label: {
            QuickBrowserIcon(browser: browser, size: 30)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? selectionColor : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(selected ? selectionStroke : Color.clear, lineWidth: selected && contrast == .increased ? 2 : 1)
                        )
                )
                .overlay(alignment: .bottomTrailing) {
                    Text(browser.shortcutKey)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .pickerBadgeChip()
                        .offset(x: 2, y: 2)
                }
                .overlay(alignment: .topLeading) {
                    if selected && differentiateWithoutColor {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PickerPressButtonStyle())
        .onHover { hovering in if hovering { selectedBrowserID = browser.id; moreSelected = false } }
        .accessibilityLabel(quickPickerAccessibilityLabel(browser, privateMode: privateMode))
        .accessibilityValue(quickPickerAccessibilityValue(isSelected: selected, privateMode: privateMode))
    }

    private var moreEntry: some View {
        let selected = moreSelected
        return Button {
            selectedBrowserID = nil
            moreSelected = true
            activateSelection()
        } label: {
            Image(systemName: "folder.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? selectionColor : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(selected ? selectionStroke : Color.clear, lineWidth: selected && contrast == .increased ? 2 : 1)
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PickerPressButtonStyle())
        .onHover { hovering in if hovering { selectedBrowserID = nil; moreSelected = true } }
        .accessibilityLabel("More browsers and profiles")
        .accessibilityValue(selected ? "selected" : "not selected")
    }

    private var selectionCaption: String {
        if moreSelected { return "More browsers and profiles" }
        guard let selectedBrowserID,
              let browser = directBrowsers.first(where: { $0.id == selectedBrowserID }) else {
            return "Choose a browser"
        }
        return browser.name
    }

    private var selectionColor: Color { privateMode ? Color.purple.opacity(0.28) : Color.pickerAccent.opacity(0.25) }
    private var selectionStroke: Color { privateMode ? .purple : .pickerAccent }

    private func updateSelection(x: CGFloat) {
        guard let index = MinimalPickerGeometry.selectedIndex(at: x, entryCount: entryCount) else { return }
        if index < directBrowsers.count {
            selectedBrowserID = directBrowsers[index].id
            moreSelected = false
        } else {
            selectedBrowserID = nil
            moreSelected = true
        }
    }

    private func activateSelection() {
        if moreSelected, !overflowBrowsers.isEmpty {
            guard activationGuard.begin() else { return }
            overflowSelectedBrowserID = overflowBrowsers.first?.id
            overflowPresented = true
        } else if let selectedBrowserID,
                  let browser = directBrowsers.first(where: { $0.id == selectedBrowserID }) {
            guard activationGuard.begin() else { return }
            openBrowser(browser)
        } else {
            return
        }
        DispatchQueue.main.async { activationGuard.reset() }
    }
}

private struct QuickPickerOverflowList: View {
    let browsers: [BrowserConfig]
    @Binding var selectedBrowserID: UUID?
    let privateMode: Bool
    let close: () -> Void
    let openBrowser: (BrowserConfig) -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("More Browsers & Profiles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if privateMode {
                    Label("Private", systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("picker.privateModeIndicator")
                }
                Spacer(minLength: 8)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PickerPressButtonStyle())
            }
            .padding(.horizontal, 7)
            .padding(.top, 4)
            .accessibilityElement(children: .contain)

            ScrollView(.vertical, showsIndicators: browsers.count > 5) {
                VStack(spacing: 2) {
                    ForEach(browsers) { browser in
                        let selected = selectedBrowserID == browser.id
                        Button {
                            selectedBrowserID = browser.id
                            openBrowser(browser)
                        } label: {
                            HStack(spacing: 8) {
                                QuickBrowserIcon(browser: browser, size: 25)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(quickBrowserName(browser)).font(.system(size: 11, weight: .semibold))
                                    if let profile = quickProfileName(browser) {
                                        Text(profile).font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                if selected && differentiateWithoutColor {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selected ? (privateMode ? Color.purple.opacity(0.25) : Color.pickerAccent.opacity(0.2)) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(
                                                selected ? (privateMode ? Color.purple : Color.pickerAccent) : Color.clear,
                                                lineWidth: selected && contrast == .increased ? 2 : 1
                                            )
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PickerPressButtonStyle())
                        .onHover { hovering in if hovering { selectedBrowserID = browser.id } }
                        .accessibilityLabel(quickPickerAccessibilityLabel(browser, privateMode: privateMode))
                        .accessibilityValue(quickPickerAccessibilityValue(isSelected: selected, privateMode: privateMode))
                    }
                }
            }
            .frame(maxHeight: 245)
        }
        .padding(6)
        .frame(width: 220)
        .pickerPanelSurface()
        .accessibilityIdentifier("picker.moreList")
    }
}

private struct QuickBrowserIcon: View {
    let browser: BrowserConfig
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = BrowserManager.icon(forBrowserBundleID: browser.bundleId) {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: "globe").resizable().scaledToFit().padding(size * 0.2).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }
}

private func quickBrowserName(_ browser: BrowserConfig) -> String {
    guard browser.profile != nil, let dash = browser.name.range(of: " - ") else { return browser.name }
    return String(browser.name[..<dash.lowerBound])
}

private func quickPickerAccessibilityLabel(_ browser: BrowserConfig, privateMode: Bool) -> String {
    privateMode ? "Open in \(browser.name) privately" : "Open in \(browser.name)"
}

private func quickPickerAccessibilityValue(isSelected: Bool, privateMode: Bool) -> String {
    let selection = isSelected ? "selected" : "not selected"
    return privateMode ? "\(selection), private mode" : selection
}

private func quickProfileName(_ browser: BrowserConfig) -> String? {
    guard browser.profile != nil else { return nil }
    if let dash = browser.name.range(of: " - ") {
        let suffix = String(browser.name[dash.upperBound...])
        return suffix.isEmpty ? browser.profile : suffix
    }
    return browser.profile
}
