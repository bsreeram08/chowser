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

struct RadialPickerView: View {
    let browsers: [BrowserConfig]
    let shape: RadialPickerShape
    @Binding var selectedBrowserID: UUID?
    @Binding var moreSelected: Bool
    @Binding var overflowPresented: Bool
    @Binding var overflowSelectedBrowserID: UUID?
    let privateMode: Bool
    let openBrowser: (BrowserConfig) -> Void
    @State private var activationInProgress = false

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
                .blur(radius: overflowPresented ? 2 : 0)

            if overflowPresented {
                QuickPickerOverflowList(
                    browsers: overflowBrowsers,
                    selectedBrowserID: $overflowSelectedBrowserID,
                    privateMode: privateMode,
                    close: { overflowPresented = false },
                    openBrowser: openBrowser
                )
                .offset(overflowListOffset)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
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
        .animation(.spring(response: 0.2, dampingFraction: 0.82), value: overflowPresented)
    }

    private var directionalOrbit: some View {
        let angles = RadialPickerGeometry.centerAngles(itemCount: entries.count, shape: shape)
        let step = entries.isEmpty ? 0 : shape.span / CGFloat(entries.count)
        let gap: CGFloat = shape.span >= .pi * 2 - 0.001 ? 0.025 : 0.04

        return ZStack {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                let isSelected = selectionIndex == index
                let wedge = RadialPickerGeometry.wedgePath(
                    center: center,
                    innerRadius: RadialPickerGeometry.innerRadius,
                    outerRadius: RadialPickerGeometry.outerRadius,
                    startAngle: angles[index] - step / 2 + gap,
                    endAngle: angles[index] + step / 2 - gap
                )

                if isSelected {
                    wedge
                        .fill(privateMode ? Color.purple.opacity(0.24) : Color.pickerAccent.opacity(0.2))
                        .overlay(
                            wedge.stroke(
                                privateMode ? Color.purple.opacity(0.9) : Color.pickerAccentText.opacity(0.85),
                                lineWidth: 1.5
                            )
                        )
                        .shadow(
                            color: privateMode ? Color.purple.opacity(0.22) : Color.pickerAccent.opacity(0.18),
                            radius: 10
                        )
                        .transition(.opacity)
                }

                Button {
                    select(index: index)
                    activateSelection()
                } label: {
                    radialEntry(entry, selected: isSelected)
                }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .position(
                        x: center.x + cos(angles[index]) * RadialPickerGeometry.itemRadius,
                        y: center.y + sin(angles[index]) * RadialPickerGeometry.itemRadius
                    )
                    .accessibilityLabel(accessibilityLabel(for: entry))
                    .accessibilityValue(isSelected ? "selected" : "not selected")
            }
        }
    }

    @ViewBuilder
    private func radialEntry(_ entry: QuickPickerEntry, selected: Bool) -> some View {
        VStack(spacing: 4) {
            if let browser = entry.browser {
                QuickBrowserIcon(browser: browser, size: 34)
            } else {
                Image(systemName: "folder.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }

            VStack(spacing: 0) {
                Text(entry.browser.map(quickBrowserName) ?? "More")
                    .font(.system(size: 9, weight: selected ? .bold : .semibold))
                if let browser = entry.browser, let profile = quickProfileName(browser) {
                    Text(profile).font(.system(size: 7)).foregroundStyle(.secondary)
                } else if entry.isMore {
                    Text("\(overflowBrowsers.count) more").font(.system(size: 7)).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .frame(width: 64)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(selected ? 0.96 : 0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            selected
                                ? (privateMode ? Color.purple.opacity(0.9) : Color.pickerAccentText.opacity(0.85))
                                : Color.primary.opacity(0.12),
                            lineWidth: selected ? 1.5 : 0.8
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: selected ? 10 : 7, y: 3)
        )
        .scaleEffect(selected ? 1.1 : 1)
        .animation(.spring(response: 0.16, dampingFraction: 0.72), value: selected)
    }

    private var overflowListOffset: CGSize {
        guard shape.span < .pi * 2 - 0.001 else { return .zero }
        let distance: CGFloat = 130
        return CGSize(width: cos(shape.centerAngle) * distance, height: sin(shape.centerAngle) * distance)
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
        guard !activationInProgress else { return }
        if moreSelected, !overflowBrowsers.isEmpty {
            activationInProgress = true
            overflowSelectedBrowserID = overflowBrowsers.first?.id
            overflowPresented = true
        } else if let selectedBrowserID,
                  let browser = directBrowsers.first(where: { $0.id == selectedBrowserID }) {
            activationInProgress = true
            openBrowser(browser)
        } else {
            return
        }
        DispatchQueue.main.async { activationInProgress = false }
    }

    private func accessibilityLabel(for entry: QuickPickerEntry) -> String {
        guard let browser = entry.browser else { return "More browsers and profiles" }
        return "Open in \(browser.name)"
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

    private var directBrowsers: [BrowserConfig] { Array(browsers.prefix(8)) }
    private var overflowBrowsers: [BrowserConfig] { Array(browsers.dropFirst(8)) }
    private var entryCount: Int { directBrowsers.count + (overflowBrowsers.isEmpty ? 0 : 1) }
    private var stripWidth: CGFloat { CGFloat(entryCount) * 43 + 14 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                Text(selectionCaption)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(height: 14)

                HStack(spacing: 3) {
                    ForEach(Array(directBrowsers.enumerated()), id: \.element.id) { index, browser in
                        minimalEntry(browser: browser, index: index)
                    }
                    if !overflowBrowsers.isEmpty { moreEntry(index: directBrowsers.count) }
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
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
        .animation(.spring(response: 0.2, dampingFraction: 0.82), value: overflowPresented)
    }

    private func minimalEntry(browser: BrowserConfig, index: Int) -> some View {
        let selected = !moreSelected && selectedBrowserID == browser.id
        return QuickBrowserIcon(browser: browser, size: 30)
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? selectionColor : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(selected ? selectionStroke : Color.clear, lineWidth: 1))
            )
            .overlay(alignment: .bottomTrailing) {
                Text(browser.shortcutKey)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .pickerBadgeChip()
                    .offset(x: 2, y: 2)
            }
            .scaleEffect(selected ? 1.05 : 1)
            .contentShape(Rectangle())
            .onHover { hovering in if hovering { selectedBrowserID = browser.id; moreSelected = false } }
            .onTapGesture { selectedBrowserID = browser.id; moreSelected = false; openBrowser(browser) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Open in \(browser.name)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { selectedBrowserID = browser.id; moreSelected = false; openBrowser(browser) }
    }

    private func moreEntry(index: Int) -> some View {
        let selected = moreSelected
        return Image(systemName: "folder.fill")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? selectionColor : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(selected ? selectionStroke : Color.clear, lineWidth: 1))
            )
            .contentShape(Rectangle())
            .onHover { hovering in if hovering { selectedBrowserID = nil; moreSelected = true } }
            .onTapGesture {
                selectedBrowserID = nil
                moreSelected = true
                overflowSelectedBrowserID = overflowBrowsers.first?.id
                overflowPresented = true
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("More browsers and profiles")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                selectedBrowserID = nil
                moreSelected = true
                overflowSelectedBrowserID = overflowBrowsers.first?.id
                overflowPresented = true
            }
    }

    private var selectionCaption: String {
        if moreSelected { return "More browsers and profiles" }
        guard let selectedBrowserID,
              let browser = directBrowsers.first(where: { $0.id == selectedBrowserID }) else {
            return "Choose a browser"
        }
        return browser.name + (privateMode ? " · Private" : "")
    }

    private var selectionColor: Color { privateMode ? Color.purple.opacity(0.28) : Color.pickerAccent.opacity(0.25) }
    private var selectionStroke: Color { privateMode ? .purple : .pickerAccentText }

    private func updateSelection(x: CGFloat) {
        let localX = x - 7
        guard localX >= 0, localX < CGFloat(entryCount) * 43 else { return }
        let index = min(entryCount - 1, max(0, Int(localX / 43)))
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
            overflowSelectedBrowserID = overflowBrowsers.first?.id
            overflowPresented = true
        } else if let selectedBrowserID,
                  let browser = directBrowsers.first(where: { $0.id == selectedBrowserID }) {
            openBrowser(browser)
        }
    }
}

private struct QuickPickerOverflowList: View {
    let browsers: [BrowserConfig]
    @Binding var selectedBrowserID: UUID?
    let privateMode: Bool
    let close: () -> Void
    let openBrowser: (BrowserConfig) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("More Browsers & Profiles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 7)
            .padding(.top, 4)

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
                                    Text(quickBrowserName(browser)).font(.system(size: 10, weight: .semibold))
                                    if let profile = quickProfileName(browser) {
                                        Text(profile).font(.system(size: 8)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? (privateMode ? Color.purple.opacity(0.25) : Color.pickerAccent.opacity(0.2)) : Color.clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in if hovering { selectedBrowserID = browser.id } }
                        .accessibilityLabel("Open in \(browser.name)")
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

private func quickProfileName(_ browser: BrowserConfig) -> String? {
    guard browser.profile != nil else { return nil }
    if let dash = browser.name.range(of: " - ") {
        let suffix = String(browser.name[dash.upperBound...])
        return suffix.isEmpty ? browser.profile : suffix
    }
    return browser.profile
}
