import AppKit
import Foundation

/// Coverage for turning a decoded capture into the inspector's model.
///
/// The converter is the one place that builds `LookinDisplayItem` trees in
/// memory: outside the server, which sets every field explicitly, and outside
/// the archive decoder, which supplies compatibility defaults for absent keys.
/// Any field whose Objective-C default differs from what the reader expects is
/// therefore a trap here, and the two cases below are the two already fallen
/// into. Both share a failure signature — the import succeeds, the tree is
/// built, and the reader is then unusable: an assertion while drawing the
/// dashboard, and a preview that receives nothing.
@main
struct LKXcodeViewHierarchyConverterTests {
    static func main() {
        testColorAttributesCarryRGBAComponents()
        testEveryConvertedNodeOptsIntoScreenshots()
        testAppKitTopLevelFollowsXcodeSidebar()
        testUIKitTopLevelFollowsXcodeSidebar()
        print("Xcode view hierarchy converter tests passed")
    }

    // MARK: - Dashboard contract

    /// A `LookinAttrTypeUIColor` value is an RGBA array of four numbers in
    /// 0...1 (`LookinAttrType.h`); the dashboard's colour card asserts on
    /// anything else. Handing it an `NSColor` raised on the first card drawn
    /// and aborted opening the document.
    private static func testColorAttributesCarryRGBAComponents() {
        let file = convertedFixture()
        var colorAttributes: [(identifier: String, value: Any?)] = []
        walk(file.hierarchyInfo.displayItems) { item in
            for group in item.attributesGroupList ?? [] {
                for section in group.attrSections ?? [] {
                    for attribute in section.attributes ?? [] where attribute.attrType == .uiColor {
                        colorAttributes.append((attribute.identifier, attribute.value))
                    }
                }
            }
        }
        expect(colorAttributes.count == 2,
               "expected the layer's background and border colours, got \(colorAttributes.count)")

        for (identifier, value) in colorAttributes {
            guard let components = value as? [NSNumber] else {
                fail("\(identifier) carries \(value.map { "\(type(of: $0))" } ?? "nil") rather than an RGBA NSNumber array")
            }
            expect(components.count == 4, "\(identifier) needs 4 components, got \(components.count)")
            expect(NSColor.lookin_color(fromRGBAComponents: components) != nil,
                   "\(identifier) does not decode as a colour")
        }

        let background = colorAttributes
            .first { $0.identifier == LookinAttr_ViewLayer_BgColor_BgColor }?
            .value as? [NSNumber]
        expect(background?.map(\.doubleValue) == [0.5, 0.25, 1, 1],
               "background colour components mismatch: \(String(describing: background))")
    }

    // MARK: - Preview contract

    /// `shouldCaptureImage` is NO on a freshly initialised item, and the host
    /// reads NO as "the user's config excluded this layer": it marks the node
    /// and its whole subtree `noPreview`, so the preview receives nothing.
    /// Every node the converter emits — window, view, layout guide, cell —
    /// has to opt in explicitly, the way the server does for each kind.
    private static func testEveryConvertedNodeOptsIntoScreenshots() {
        let file = convertedFixture()
        var kindsSeen: Set<LookinDisplayItemNodeKind> = []
        walk(file.hierarchyInfo.displayItems) { item in
            kindsSeen.insert(item.nodeKind)
            expect(item.shouldCaptureImage,
                   "\(item) (nodeKind \(item.nodeKind.rawValue)) would be dropped from the preview: shouldCaptureImage is NO")
        }
        expect(kindsSeen == [.window, .view, .layoutGuide, .cell],
               "fixture must cover window, view, layout guide and cell nodes; saw \(kindsSeen.map(\.rawValue).sorted())")
    }

    // MARK: - Top-level contract

    /// The top level must come out the way Xcode's sidebar lists a capture,
    /// which is not the order — or the membership — of the capture's root
    /// groups. Xcode lists window controllers first (each with its windows),
    /// then windows no controller owns, with the key window's controller
    /// moved to the front; child windows join the list after the root ones;
    /// and of the root views only an NSTouchBarView with children survives.
    /// The first real capture opened (Finder) showed a detached status bar
    /// and path bar as top-level rows beside the windows — the two root
    /// views this rule now drops.
    private static func testAppKitTopLevelFollowsXcodeSidebar() {
        let file = convert(appKitSidebarFixture())
        let rootItems = file.hierarchyInfo.displayItems ?? []

        expect(rootItems.map(displayedObjectIdentifier) == [0x3, 0x1, 0x2, 0x4, 0x60],
               "top level should be key window's controller, other controller, unowned windows, touch bar; got \(rootItems.map(displayedObjectIdentifier).map { String($0, radix: 16) })")
        expect(rootItems.map(\.nodeKind) == [.window, .window, .window, .window, .view],
               "top-level kinds mismatch: \(rootItems.map(\.nodeKind.rawValue))")
        expect(rootItems.map(\.representedAsKeyWindow) == [true, false, false, false, false],
               "only the application's key window is marked key")
        expect(rootItems[1].hostWindowControllerObject?.oid == 0xc1,
               "a controller-owned window row carries its controller")
        expect(rootItems[2].hostWindowControllerObject == nil,
               "an unowned window row carries no controller")

        let childWindowRow = rootItems[3]
        expect(childWindowRow.windowObject?.oid == 0x4, "the child window is listed as a window of its own")
        expect(rootItems[0].subitems?.map(displayedObjectIdentifier) == [0x30],
               "a child window must not be nested under its parent as a view; got \(String(describing: rootItems[0].subitems?.map(displayedObjectIdentifier)))")

        var everyIdentifier: Set<UInt> = []
        walk(rootItems) { everyIdentifier.insert(displayedObjectIdentifier($0)) }
        expect(!everyIdentifier.contains(0x50) && !everyIdentifier.contains(0x51),
               "a detached view controller view must not appear anywhere in the tree")
        expect(!everyIdentifier.contains(0x70), "a childless NSTouchBarView is not a top-level row")
    }

    /// On UIKit the window owners are scenes, and Xcode gives each a row of
    /// its own with its windows beneath — the shape a live session produces
    /// too. Windows that are internal or invisible are left out, except
    /// keyboard and iMessage extension windows, whose view controllers are
    /// the user's code; a system overlay window is always left out, and a
    /// remote keyboard window never earns the exception.
    private static func testUIKitTopLevelFollowsXcodeSidebar() {
        let file = convert(uiKitSidebarFixture())
        let rootItems = file.hierarchyInfo.displayItems ?? []

        expect(rootItems.map(displayedObjectIdentifier) == [0xf2, 0xf1, 0x4],
               "top level should be the key window's scene, the other scene, then the sceneless window; got \(rootItems.map(displayedObjectIdentifier).map { String($0, radix: 16) })")
        expect(rootItems.map(\.nodeKind) == [.windowScene, .windowScene, .window],
               "top-level kinds mismatch: \(rootItems.map(\.nodeKind.rawValue))")
        expect(rootItems[0].subitems?.map(displayedObjectIdentifier) == [0x2],
               "the key scene lists its one visible window")
        expect(rootItems[1].subitems?.map(displayedObjectIdentifier) == [0x1, 0x6],
               "the other scene keeps its visible window and the keyboard window, dropping the internal one; got \(String(describing: rootItems[1].subitems?.map(displayedObjectIdentifier)))")
        expect(rootItems[0].representedAsKeyWindow && rootItems[0].subitems?.first?.representedAsKeyWindow == true,
               "the key window and the scene holding it are both marked key")
        expect(!rootItems[1].representedAsKeyWindow && !rootItems[2].representedAsKeyWindow,
               "no other row is marked key")
        expect(rootItems[0].customDisplayTitle == "UIWindowScene – Main (Foreground Active)",
               "scene title mismatch: \(String(describing: rootItems[0].customDisplayTitle))")
        expect(rootItems[0].windowObject?.classChainList?.first == "UIWindowScene",
               "a scene node rides windowObject like the server's")

        var everyIdentifier: Set<UInt> = []
        walk(rootItems) { item in
            everyIdentifier.insert(displayedObjectIdentifier(item))
            expect(item.shouldCaptureImage, "\(item) would be dropped from the preview: shouldCaptureImage is NO")
        }
        for skippedIdentifier: UInt in [0x3, 0x5, 0x7, 0x8] {
            expect(!everyIdentifier.contains(skippedIdentifier),
                   "window 0x\(String(skippedIdentifier, radix: 16)) should have been skipped")
        }
    }

    // MARK: - Fixture

    /// The capture-side shape of a detached AppKit view alongside windows
    /// with and without controllers, a child window, and touch bars:
    ///
    /// - controllers `0xc1` → window `0x1`, `0xc2` → window `0x3` (key);
    /// - window `0x2` has no controller; window `0x3` has child window `0x4`;
    /// - root views: the four window frames, a detached `TStatusBar` (`0x50`)
    ///   owned by a view controller, an `NSTouchBarView` with a child (`0x60`)
    ///   and one without (`0x70`).
    private static func appKitSidebarFixture() -> LKXcodeViewHierarchyObjectGraph {
        let builder = LKXcodeViewHierarchyObjectGraphBuilder()
        builder.ingesting(response: response(groups: [
            group("com.apple.AppKit.NSApplication", objects: [
                object("0xa0", className: "NSApplication", additionalGroups: [
                    group("com.apple.AppKit.NSWindow", objects: [reference("0x1"), reference("0x2"), reference("0x3")]),
                ]),
            ]),
            group("com.apple.AppKit.NSWindowController", objects: [
                object("0xc1", className: "NSWindowController", additionalGroups: [
                    group("com.apple.AppKit.NSWindow", objects: [reference("0x1")]),
                ]),
                object("0xc2", className: "NSWindowController", additionalGroups: [
                    group("com.apple.AppKit.NSWindow", objects: [reference("0x3")]),
                ]),
            ]),
            group("com.apple.AppKit.NSWindow", objects: [
                object("0x1", className: "NSWindow", additionalGroups: [
                    group("com.apple.AppKit.NSView", objects: [reference("0x10")]),
                    group("com.apple.AppKit.NSWindowController", objects: [reference("0xc1")]),
                ]),
                object("0x2", className: "NSWindow", additionalGroups: [
                    group("com.apple.AppKit.NSView", objects: [reference("0x20")]),
                ]),
                object(
                    "0x3", className: "NSWindow",
                    childGroup: group("com.apple.AppKit.NSWindow", objects: [
                        object("0x4", className: "NSPanel", additionalGroups: [
                            group("com.apple.AppKit.NSView", objects: [reference("0x40")]),
                        ]),
                    ]),
                    additionalGroups: [
                        group("com.apple.AppKit.NSView", objects: [reference("0x30")]),
                        group("com.apple.AppKit.NSWindowController", objects: [reference("0xc2")]),
                    ]
                ),
            ]),
            group("com.apple.AppKit.NSView", objects: [
                object("0x10", className: "NSNextStepFrame"),
                object("0x20", className: "NSNextStepFrame"),
                object("0x30", className: "NSThemeFrame"),
                object("0x40", className: "NSNextStepFrame"),
                object(
                    "0x50", className: "TStatusBar",
                    childGroup: group("com.apple.AppKit.NSView", objects: [object("0x51", className: "NSView")]),
                    additionalGroups: [
                        group("com.apple.AppKit.NSViewController", objects: [
                            object("0x55", className: "TStatusBarController"),
                        ]),
                    ]
                ),
                object(
                    "0x60", className: "NSTouchBarView",
                    childGroup: group("com.apple.AppKit.NSView", objects: [object("0x61", className: "NSView")])
                ),
                object("0x70", className: "NSTouchBarView"),
            ]),
        ]))
        builder.ingesting(response: response(properties: [
            "0xa0.keyWindow": propertyDescription(name: "keyWindow", format: "public.plain-text", value: "0x3"),
        ]))
        return builder.build()
    }

    /// The capture-side shape of a UIKit app with two scenes:
    ///
    /// - scene `0xf1` owns windows `0x1` (visible), `0x3` (internal), `0x6`
    ///   (internal, hosting a `UIInputViewController`) and `0x8` (a
    ///   `UIRemoteKeyboardWindow` hosting the same);
    /// - scene `0xf2` owns window `0x2`, the application's key window;
    /// - windows `0x4` (visible), `0x5` (invisible) and `0x7` (a system
    ///   overlay window) belong to no scene.
    private static func uiKitSidebarFixture() -> LKXcodeViewHierarchyObjectGraph {
        func window(
            _ objectIdentifier: String,
            className: String = "UIWindow",
            scene: String? = nil,
            controller: [String: Any]? = nil
        ) -> [String: Any] {
            var additionalGroups: [[String: Any]] = []
            if let scene {
                additionalGroups.append(group("com.apple.UIKit.UIScene", objects: [reference(scene)]))
            }
            if let controller {
                additionalGroups.append(group("com.apple.UIKit.UIViewController", objects: [controller]))
            }
            return object(
                objectIdentifier, className: className,
                childGroup: group("com.apple.UIKit.UIView", objects: [
                    object(objectIdentifier + "1", className: "UIView"),
                ]),
                additionalGroups: additionalGroups
            )
        }
        func flags(_ objectIdentifier: String, internal isInternal: Bool, visible: Bool) -> [String: Any] {
            [
                "\(objectIdentifier).internal": propertyDescription(name: "internal", format: "b", value: isInternal ? "1" : "0"),
                "\(objectIdentifier).visible": propertyDescription(name: "visible", format: "b", value: visible ? "1" : "0"),
            ]
        }
        // The user's controller sits one level down in the keyboard window's
        // controller tree, which Xcode walks rather than just the top level.
        func keyboardController(_ objectIdentifier: String) -> [String: Any] {
            object(
                objectIdentifier, className: "UICompatibilityInputViewController",
                childGroup: group("com.apple.UIKit.UIViewController", objects: [
                    object(objectIdentifier + "1", className: "UIInputViewController"),
                ])
            )
        }

        let builder = LKXcodeViewHierarchyObjectGraphBuilder()
        builder.ingesting(response: response(groups: [
            group("com.apple.UIKit.UIApplication", objects: [
                object("0xa0", className: "UIApplication", additionalGroups: [
                    group("com.apple.UIKit.UIWindow", objects: [reference("0x1"), reference("0x2")]),
                ]),
            ]),
            group("com.apple.UIKit.UIScene", objects: [
                object("0xf1", className: "UIWindowScene", additionalGroups: [
                    group("com.apple.UIKit.UIWindow", objects: [reference("0x1"), reference("0x3"), reference("0x6"), reference("0x8")]),
                ]),
                object("0xf2", className: "UIWindowScene", additionalGroups: [
                    group("com.apple.UIKit.UIWindow", objects: [reference("0x2")]),
                ]),
            ]),
            group("com.apple.UIKit.UIWindow", objects: [
                window("0x1", scene: "0xf1"),
                window("0x2", scene: "0xf2"),
                window("0x3", scene: "0xf1"),
                window("0x4"),
                window("0x5"),
                window("0x6", className: "UITextEffectsWindow", scene: "0xf1", controller: keyboardController("0x66")),
                window("0x7", className: "_UIWindowSystemOverlayWindow"),
                window("0x8", className: "UIRemoteKeyboardWindow", scene: "0xf1", controller: keyboardController("0x88")),
            ]),
        ]))
        var properties: [String: Any] = [
            "0xa0.keyWindow": propertyDescription(name: "keyWindow", format: "public.plain-text", value: "0x2"),
            "0xf2.title": propertyDescription(name: "title", format: "public.plain-text", value: "Main"),
            "0xf2.activationState": propertyDescription(name: "activationState", format: "integer", value: "0"),
        ]
        properties.merge(flags("0x1", internal: false, visible: true)) { current, _ in current }
        properties.merge(flags("0x2", internal: false, visible: true)) { current, _ in current }
        properties.merge(flags("0x3", internal: true, visible: true)) { current, _ in current }
        properties.merge(flags("0x4", internal: false, visible: true)) { current, _ in current }
        properties.merge(flags("0x5", internal: false, visible: false)) { current, _ in current }
        properties.merge(flags("0x6", internal: true, visible: true)) { current, _ in current }
        properties.merge(flags("0x7", internal: false, visible: true)) { current, _ in current }
        properties.merge(flags("0x8", internal: true, visible: true)) { current, _ in current }
        builder.ingesting(response: response(properties: properties))
        return builder.build()
    }

    /// The object a row stands for, whichever slot its kind rides.
    private static func displayedObjectIdentifier(_ item: LookinDisplayItem) -> UInt {
        (item.kindObject ?? item.windowObject ?? item.viewObject ?? item.layerObject)?.oid ?? 0
    }

    /// An AppKit capture: one window whose content view owns a layer carrying
    /// background and border colours and a layout guide, plus a control
    /// subview with a cell. Every node kind the converter emits appears once.
    private static func convertedFixture() -> LookinHierarchyFile {
        let builder = LKXcodeViewHierarchyObjectGraphBuilder()
        builder.ingesting(response: response(groups: [
            group("com.apple.AppKit.NSWindow", objects: [
                object("0x1", className: "NSWindow", additionalGroups: [
                    group("com.apple.AppKit.NSView", objects: [reference("0x10")]),
                ]),
            ]),
            group("com.apple.AppKit.NSView", objects: [
                object(
                    "0x10", className: "NSView",
                    childGroup: group("com.apple.AppKit.NSView", objects: [
                        object("0x11", className: "NSButton", additionalGroups: [
                            group("com.apple.AppKit.NSCell", objects: [
                                object("0x40", className: "NSButtonCell"),
                            ]),
                        ]),
                    ]),
                    additionalGroups: [
                        group("com.apple.QuartzCore.CALayer", objects: [object("0x20", className: "CALayer")]),
                        group("com.apple.AppKit.NSLayoutGuide", objects: [
                            object("0x30", className: "NSLayoutGuide"),
                        ]),
                    ]
                ),
            ]),
        ]))
        builder.ingesting(response: response(properties: [
            "0x20.backgroundColor": propertyDescription(
                name: "backgroundColor", format: "color",
                value: color(["0x1p-1", "0x1p-2", "0x1p+0", "0x1p+0"])
            ),
            "0x20.borderColor": propertyDescription(
                name: "borderColor", format: "color",
                value: color(["0x0p+0", "0x0p+0", "0x0p+0", "0x1p-1"])
            ),
        ]))

        return convert(builder.build())
    }

    /// Runs the converter over a graph with no recovered pixels.
    private static func convert(_ graph: LKXcodeViewHierarchyObjectGraph) -> LookinHierarchyFile {
        let bundle = LKXcodeViewHierarchyBundle(
            metadata: LKXcodeViewHierarchyBundleMetadata(
                documentVersion: "1", runnableDisplayName: "Fixture", runnableProcessIdentifier: 1
            ),
            graph: graph,
            failedResponseCount: 0,
            succeededResponseCount: 2
        )
        let screenshots = LKXcodeViewHierarchyScreenshots(
            soloByObjectIdentifier: [:], groupByObjectIdentifier: [:], failedArchiveIdentifiers: []
        )
        do {
            return try LKXcodeViewHierarchyConverter.makingHierarchyFile(from: bundle, screenshots: screenshots)
        } catch {
            fail("conversion failed: \(error)")
        }
    }

    private static func response(
        groups: [[String: Any]] = [],
        properties: [String: Any] = [:]
    ) -> [String: Any] {
        var topLevelGroups: [String: Any] = [:]
        for group in groups {
            topLevelGroups[group["groupingID"] as? String ?? ""] = group
        }
        return [
            "version": NSNumber(value: 2),
            "topLevelGroups": topLevelGroups,
            "topLevelPropertyDescriptions": properties,
        ]
    }

    private static func group(_ groupingIdentifier: String, objects: [[String: Any]]) -> [String: Any] {
        ["groupingID": groupingIdentifier, "debugHierarchyObjects": objects]
    }

    private static func object(
        _ objectIdentifier: String,
        className: String,
        childGroup: [String: Any]? = nil,
        additionalGroups: [[String: Any]]? = nil
    ) -> [String: Any] {
        var object: [String: Any] = ["objectID": objectIdentifier, "className": className]
        if let childGroup { object["childGroup"] = childGroup }
        if let additionalGroups { object["additionalGroups"] = additionalGroups }
        return object
    }

    private static func reference(_ objectIdentifier: String) -> [String: Any] {
        [
            "objectID": objectIdentifier,
            "propertyVisibility": NSNumber(value: 1),
            "propertyLogicalType": "DebugHierarchyLogicalPropertyTypePointer",
        ]
    }

    private static func propertyDescription(name: String, format: String, value: Any) -> [String: Any] {
        [
            "propertyName": name,
            "propertyFormat": format,
            "propertyValue": value,
            "fetchStatus": NSNumber(value: 4),
        ]
    }

    /// The capture's colour structure: sRGB components as C99 hex floats.
    private static func color(_ hexFloatComponents: [String]) -> [String: Any] {
        [
            "colorSpaceName": "kCGColorSpaceSRGB",
            "componentValuesFormat": "CGf, CGf, CGf, CGf",
            "componentValues": hexFloatComponents,
        ]
    }

    // MARK: - Helpers

    private static func walk(_ items: [LookinDisplayItem], _ visit: (LookinDisplayItem) -> Void) {
        for item in items {
            visit(item)
            walk(item.subitems ?? [], visit)
        }
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        Foundation.exit(1)
    }
}
