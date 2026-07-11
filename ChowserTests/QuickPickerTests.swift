import Testing
import Foundation
@testable import Chowser

struct QuickPickerTests {
    @Test("Radial geometry uses a full circle away from screen edges")
    func centeredShape() {
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let shape = RadialPickerGeometry.shape(anchor: CGPoint(x: 600, y: 400), visibleFrame: frame)

        #expect(shape == .circle)
    }

    @Test("Radial geometry faces inward at an edge and corner")
    func adaptiveShapes() {
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let left = RadialPickerGeometry.shape(anchor: CGPoint(x: 20, y: 400), visibleFrame: frame)
        let topLeft = RadialPickerGeometry.shape(anchor: CGPoint(x: 20, y: 780), visibleFrame: frame)

        #expect(left.span == .pi)
        #expect(left.centerAngle == 0)
        #expect(topLeft.span < .pi)
        #expect(abs(topLeft.centerAngle - .pi / 4) < 0.001)
    }

    @Test("Radial selection honors the dead zone and starts browser 1 at the top")
    func directionalSelection() {
        let center = CGPoint(x: 190, y: 190)

        #expect(RadialPickerGeometry.selectedIndex(
            at: CGPoint(x: 190, y: 180),
            center: center,
            itemCount: 9,
            shape: .circle
        ) == nil)
        #expect(RadialPickerGeometry.selectedIndex(
            at: CGPoint(x: 190, y: 80),
            center: center,
            itemCount: 9,
            shape: .circle
        ) == 0)
    }

    @Test("Returning to the radial dead zone clears an active selection")
    func returningToDeadZoneClearsSelection() {
        let center = CGPoint(x: 190, y: 190)
        var selection = RadialPickerSelectionState()

        selection.update(
            at: CGPoint(x: 190, y: 80),
            center: center,
            itemCount: 4,
            shape: .circle
        )
        #expect(selection.index == 0)

        selection.update(
            at: CGPoint(x: 190, y: 185),
            center: center,
            itemCount: 4,
            shape: .circle
        )
        #expect(selection.index == nil)
    }

    @Test("Two radial destinations map upward and downward from the cursor")
    func twoDestinationDirections() {
        let center = CGPoint(x: 250, y: 250)

        #expect(RadialPickerGeometry.selectedIndex(
            at: CGPoint(x: 250, y: 120),
            center: center,
            itemCount: 2,
            shape: .circle
        ) == 0)
        #expect(RadialPickerGeometry.selectedIndex(
            at: CGPoint(x: 250, y: 380),
            center: center,
            itemCount: 2,
            shape: .circle
        ) == 1)
    }

    @Test("Appearance preview scales real picker content to the available canvas")
    func appearancePreviewFit() {
        #expect(AppearancePreviewLayout.scale(
            contentSize: CGSize(width: 500, height: 500),
            availableSize: CGSize(width: 250, height: 300)
        ) == 0.5)
        #expect(AppearancePreviewLayout.scale(
            contentSize: CGSize(width: 200, height: 180),
            availableSize: CGSize(width: 320, height: 260)
        ) == 1)
    }

    @Test("Appearance uses a stacked pinned preview at narrow detail widths")
    func adaptiveAppearanceLayout() {
        #expect(AppearancePreviewLayout.presentation(for: 680) == .stacked)
        #expect(AppearancePreviewLayout.presentation(for: 760) == .sideBySide)
    }

    @Test("Radial edge fan rejects movement toward the clipped side")
    func constrainedDirection() {
        let center = CGPoint(x: 190, y: 190)
        let rightFacingFan = RadialPickerShape(centerAngle: 0, span: .pi)

        #expect(RadialPickerGeometry.selectedIndex(
            at: CGPoint(x: 80, y: 190),
            center: center,
            itemCount: 9,
            shape: rightFacingFan
        ) == nil)
        #expect(RadialPickerGeometry.selectedIndex(
            at: CGPoint(x: 300, y: 190),
            center: center,
            itemCount: 9,
            shape: rightFacingFan
        ) != nil)
    }

    @Test("Radial and minimal picker layout preferences persist")
    @MainActor
    func pickerLayoutPersistence() {
        let suite = "in.sreerams.ChowserTests.quick-picker.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = BrowserManager(defaults: defaults)
        manager.pickerLayoutMode = .radial
        #expect(BrowserManager(defaults: defaults).pickerLayoutMode == .radial)

        manager.pickerLayoutMode = .minimal
        #expect(BrowserManager(defaults: defaults).pickerLayoutMode == .minimal)
    }

    @Test("Unknown picker layout preferences safely fall back to icons")
    @MainActor
    func unknownLayoutFallback() {
        let suite = "in.sreerams.ChowserTests.quick-picker-unknown.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("future-layout", forKey: "pickerLayoutMode")

        #expect(BrowserManager(defaults: defaults).pickerLayoutMode == .icons)
    }
}
