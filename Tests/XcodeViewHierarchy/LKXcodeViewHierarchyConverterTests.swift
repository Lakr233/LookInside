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

    // MARK: - Fixture

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

        let bundle = LKXcodeViewHierarchyBundle(
            metadata: LKXcodeViewHierarchyBundleMetadata(
                documentVersion: "1", runnableDisplayName: "Fixture", runnableProcessIdentifier: 1
            ),
            graph: builder.build(),
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
