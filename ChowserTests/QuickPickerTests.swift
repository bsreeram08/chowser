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
