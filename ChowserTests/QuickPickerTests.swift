import Testing
import Foundation
@testable import Chowser

struct QuickPickerTests {
    @Test("Quick picker activation guard blocks a second launch in the same run loop")
    func quickPickerActivationGuard() {
        var guardState = PickerActivationGuard()

        let firstActivation = guardState.begin()
        let duplicateActivation = guardState.begin()
        #expect(firstActivation)
        #expect(duplicateActivation == false)
        guardState.reset()
        let nextRunLoopActivation = guardState.begin()
        #expect(nextRunLoopActivation)
    }

    @Test("Minimal drag selection maps pointer positions directly to cells")
    func minimalDragSelectionGeometry() {
        #expect(MinimalPickerGeometry.selectedIndex(at: 8, entryCount: 3) == 0)
        #expect(MinimalPickerGeometry.selectedIndex(at: 51, entryCount: 3) == 1)
        #expect(MinimalPickerGeometry.selectedIndex(at: 94, entryCount: 3) == 2)
        #expect(MinimalPickerGeometry.selectedIndex(at: 6, entryCount: 3) == nil)
        #expect(MinimalPickerGeometry.selectedIndex(at: 136, entryCount: 3) == nil)
    }

    @Test("Passive destination display omits sensitive URL components")
    func passiveDestinationDisplay() throws {
        let display = PickerDestinationDisplay(
            url: try #require(URL(string: "https://example.com/account/reset%20password?token=secret#confirm"))
        )

        #expect(display.host == "example.com")
        #expect(display.path == "/account/reset password")
        #expect(display.host.contains("secret") == false)
        #expect(display.path?.contains("secret") == false)
    }

    @Test("Passive destination display hides an empty root path")
    func passiveDestinationRootPath() throws {
        let display = PickerDestinationDisplay(url: try #require(URL(string: "https://example.com/?token=secret")))

        #expect(display.host == "example.com")
        #expect(display.path == nil)
    }

    @Test("Passive destination display preserves and decodes long paths")
    func passiveDestinationLongPath() throws {
        let url = try #require(URL(string: "https://example.com/projects/a%20long%20folder/documents/final%20draft?access_token=secret#page-4"))
        let display = PickerDestinationDisplay(url: url)

        #expect(display.host == "example.com")
        #expect(display.path == "/projects/a long folder/documents/final draft")
        #expect(display.path?.contains("access_token") == false)
        #expect(display.path?.contains("page-4") == false)
    }

    @Test("Radial overflow placement follows the More wedge and stays inside the panel")
    func radialOverflowPlacement() {
        let right = QuickPickerOverflowPlacement.radial(moreAngle: 0)
        let upperLeft = QuickPickerOverflowPlacement.radial(moreAngle: -.pi * 3 / 4)

        #expect(right.offset.width == 128)
        #expect(right.offset.height == 0)
        #expect(right.anchor.x == 0)
        #expect(right.anchor.y == 0.5)

        #expect(upperLeft.offset.width >= -128)
        #expect(upperLeft.offset.height >= -109)
        #expect(upperLeft.anchor.x > 0.5)
        #expect(upperLeft.anchor.y > 0.5)
    }

    @Test("Radial wheel grows with its destination count instead of reserving the maximum canvas")
    func adaptiveRadialWheelSize() {
        let two = RadialPickerGeometry.metrics(itemCount: 2, shape: .circle)
        let four = RadialPickerGeometry.metrics(itemCount: 4, shape: .circle)
        let six = RadialPickerGeometry.metrics(itemCount: 6, shape: .circle)
        let nine = RadialPickerGeometry.metrics(itemCount: 9, shape: .circle)
        let edgeTwo = RadialPickerGeometry.metrics(
            itemCount: 2,
            shape: RadialPickerShape(centerAngle: 0, span: .pi)
        )

        #expect(two.canvasSize == 216)
        #expect(four.canvasSize == 256)
        #expect(six.canvasSize == 304)
        #expect(nine.canvasSize == 352)
        #expect(edgeTwo.canvasSize == 248)
        #expect(two.centerHubSize == 56)
        #expect(two.outerRadius < four.outerRadius)
        #expect(four.outerRadius < six.outerRadius)
        #expect(six.outerRadius < nine.outerRadius)
    }

    @Test("Radial mode keeps at most five visible destinations")
    func radialVisibleDestinationLimit() {
        for totalBrowserCount in 1...5 {
            #expect(RadialPickerGeometry.directBrowserCount(totalBrowserCount: totalBrowserCount) == totalBrowserCount)
        }

        #expect(RadialPickerGeometry.directBrowserCount(totalBrowserCount: 6) == 4)
        #expect(RadialPickerGeometry.directBrowserCount(totalBrowserCount: 8) == 4)
        #expect(RadialPickerGeometry.directBrowserCount(totalBrowserCount: 12) == 4)
    }

    @Test("Up to nine radial cards do not overlap in circle, edge, or corner layouts")
    func radialCardsDoNotOverlap() {
        let center = CGPoint(x: 250, y: 250)
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 500)
        let shapes = [
            RadialPickerShape.circle,
            RadialPickerShape(centerAngle: 0, span: .pi),
            RadialPickerShape(centerAngle: .pi / 2, span: .pi),
            RadialPickerShape(centerAngle: .pi / 4, span: .pi * 0.68),
            RadialPickerShape(centerAngle: .pi * 3 / 4, span: .pi * 0.68),
        ]

        for shape in shapes {
            for itemCount in 1...9 {
                let centers = RadialPickerGeometry.entryCenters(
                    itemCount: itemCount,
                    shape: shape,
                    center: center,
                    panelBounds: bounds
                )
                let frames = centers.map { point in
                    CGRect(
                        x: point.x - RadialPickerGeometry.entrySize.width / 2,
                        y: point.y - RadialPickerGeometry.entrySize.height / 2,
                        width: RadialPickerGeometry.entrySize.width,
                        height: RadialPickerGeometry.entrySize.height
                    )
                }
                #expect(frames.count == itemCount)
                #expect(frames.allSatisfy { bounds.insetBy(dx: 12, dy: 12).contains($0) })
                for first in frames.indices {
                    for second in frames.indices where second > first {
                        #expect(frames[first].intersects(frames[second]) == false)
                    }
                }
            }
        }
    }

    @Test("Radial overflow placement follows full-circle, edge, and corner More anchors")
    func radialOverflowPlacementForAdaptiveShapes() throws {
        let shapes = [
            RadialPickerShape.circle,
            RadialPickerShape(centerAngle: 0, span: .pi),
            RadialPickerShape(centerAngle: .pi / 4, span: .pi * 0.68),
        ]

        for shape in shapes {
            let moreAngle = try #require(RadialPickerGeometry.centerAngles(itemCount: 9, shape: shape).last)
            let placement = QuickPickerOverflowPlacement.radial(moreAngle: moreAngle)

            #expect(abs(placement.offset.width) <= 128)
            #expect(abs(placement.offset.height) <= 109)
            #expect((0...1).contains(placement.anchor.x))
            #expect((0...1).contains(placement.anchor.y))
            #expect(placement.offset.width * cos(moreAngle) >= 0)
            #expect(placement.offset.height * sin(moreAngle) >= 0)
        }
    }

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

    @Test("Every radial edge and corner fan preserves destination ordering")
    func edgeAndCornerDestinationMapping() {
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let anchors = [
            CGPoint(x: 20, y: 400),
            CGPoint(x: 1180, y: 400),
            CGPoint(x: 600, y: 20),
            CGPoint(x: 600, y: 780),
            CGPoint(x: 20, y: 20),
            CGPoint(x: 20, y: 780),
            CGPoint(x: 1180, y: 20),
            CGPoint(x: 1180, y: 780),
        ]
        let center = CGPoint(x: 250, y: 250)

        for anchor in anchors {
            let shape = RadialPickerGeometry.shape(anchor: anchor, visibleFrame: frame)
            let angles = RadialPickerGeometry.centerAngles(itemCount: 4, shape: shape)

            for (expectedIndex, angle) in angles.enumerated() {
                let location = CGPoint(
                    x: center.x + cos(angle) * 120,
                    y: center.y + sin(angle) * 120
                )
                #expect(RadialPickerGeometry.selectedIndex(
                    at: location,
                    center: center,
                    itemCount: 4,
                    shape: shape
                ) == expectedIndex)
            }
        }
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

    @Test("Even full-circle layouts straddle twelve o'clock while odd and two-item layouts retain their anchors")
    func evenFullCircleStagger() throws {
        for itemCount in [4, 6, 8] {
            let angles = RadialPickerGeometry.centerAngles(itemCount: itemCount, shape: .circle)
            let step = CGFloat.pi * 2 / CGFloat(itemCount)

            #expect(angles.first == -.pi / 2 + step / 2)
            #expect(angles.contains(where: { abs($0 + .pi / 2) < 0.001 }) == false)
            #expect(angles.contains(where: { abs($0 - .pi / 2) < 0.001 }) == false)
        }

        let two = RadialPickerGeometry.centerAngles(itemCount: 2, shape: .circle)
        let five = RadialPickerGeometry.centerAngles(itemCount: 5, shape: .circle)
        #expect(try #require(two.first) == -.pi / 2)
        #expect(try #require(two.last) == .pi / 2)
        #expect(try #require(five.first) == -.pi / 2)
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
