// LKXcodeViewHierarchyConverter.swift
//
// Turns a decoded `.viewhierarchy` capture into the model the inspector
// already knows how to display: a `LookinHierarchyFile`, which the existing
// read path opens exactly as it opens a `.lookin` archive.
//
// The whole point of producing that type rather than a new one is that no RPC
// has to be implemented. A live session answers questions on demand; an
// archive has the answers pre-materialised on the nodes, and this converter
// pre-materialises the capture's answers the same way.
//
// The capture's tree is not the inspector's tree, and three differences matter:
//
//  1. **A window's root view is an association, not a child.** A window object
//     carries no children at all; the view it hosts hangs off its
//     `com.apple.*.NSView`/`UIView` association. Reading only `childGroup`
//     from a window yields an empty hierarchy.
//  2. **Layers, constraints and view controllers are associations too**, and
//     they must stay out of the view tree. The inspector wants a view's layer
//     folded into the same node (as `layerObject`), not standing beside it.
//  3. **Layout guides and AppKit cells become child nodes**, because that is
//     the shape the inspector's node model uses for them (nodeKind
//     LayoutGuide and Cell, both riding `kindObject`).
//
// Node identity is the object's address: the capture writes `objectID` as a
// hexadecimal pointer string, and Lookin's `oid` is that same pointer as an
// integer, which is what lets recovered screenshots be keyed the way a
// `.lookin` archive keys them.

import AppKit
import Foundation

enum LKXcodeViewHierarchyConversionError: Error, CustomStringConvertible {
    case noWindowsOrRootViews

    var description: String {
        switch self {
        case .noWindowsOrRootViews:
            return "the capture contains no windows or root views to display"
        }
    }
}

enum LKXcodeViewHierarchyConverter {
    // MARK: Group identifiers

    private enum GroupIdentifier {
        static let layer = "com.apple.QuartzCore.CALayer"

        static let uiKitWindow = "com.apple.UIKit.UIWindow"
        static let uiKitView = "com.apple.UIKit.UIView"
        static let uiKitLayoutGuide = "com.apple.UIKit.UILayoutGuide"
        static let uiKitViewController = "com.apple.UIKit.UIViewController"
        static let uiKitScene = "com.apple.UIKit.UIScene"

        static let appKitWindow = "com.apple.AppKit.NSWindow"
        static let appKitView = "com.apple.AppKit.NSView"
        static let appKitLayoutGuide = "com.apple.AppKit.NSLayoutGuide"
        static let appKitViewController = "com.apple.AppKit.NSViewController"
        static let appKitWindowController = "com.apple.AppKit.NSWindowController"
        static let appKitCell = "com.apple.AppKit.NSCell"
    }

    /// Which platform's naming a capture uses; everything else follows from it.
    private struct Vocabulary {
        let isAppKit: Bool
        let windowGroup: String
        let viewGroup: String
        let layoutGuideGroup: String
        let viewControllerGroup: String
        let cellGroup: String?
        let windowControllerGroup: String?

        static let uiKit = Vocabulary(
            isAppKit: false,
            windowGroup: GroupIdentifier.uiKitWindow,
            viewGroup: GroupIdentifier.uiKitView,
            layoutGuideGroup: GroupIdentifier.uiKitLayoutGuide,
            viewControllerGroup: GroupIdentifier.uiKitViewController,
            cellGroup: nil,
            windowControllerGroup: nil
        )

        static let appKit = Vocabulary(
            isAppKit: true,
            windowGroup: GroupIdentifier.appKitWindow,
            viewGroup: GroupIdentifier.appKitView,
            layoutGuideGroup: GroupIdentifier.appKitLayoutGuide,
            viewControllerGroup: GroupIdentifier.appKitViewController,
            cellGroup: GroupIdentifier.appKitCell,
            windowControllerGroup: GroupIdentifier.appKitWindowController
        )
    }

    // MARK: Entry point

    static func makingHierarchyFile(
        from bundle: LKXcodeViewHierarchyBundle,
        screenshots: LKXcodeViewHierarchyScreenshots
    ) throws -> LookinHierarchyFile {
        let graph = bundle.graph
        let vocabulary = graph.rootGroups.contains { $0.groupingIdentifier.hasPrefix("com.apple.AppKit.") }
            ? Vocabulary.appKit
            : Vocabulary.uiKit

        let displayItems = makingRootDisplayItems(graph: graph, vocabulary: vocabulary)
        guard !displayItems.isEmpty else { throw LKXcodeViewHierarchyConversionError.noWindowsOrRootViews }

        let hierarchyInfo = LookinHierarchyInfo()
        hierarchyInfo.displayItems = displayItems
        hierarchyInfo.serverVersion = Int32(LOOKIN_SERVER_VERSION)
        hierarchyInfo.appInfo = makingAppInfo(from: bundle, vocabulary: vocabulary)

        let file = LookinHierarchyFile()
        file.serverVersion = Int32(LOOKIN_SERVER_VERSION)
        file.hierarchyInfo = hierarchyInfo
        file.soloScreenshots = keyingByObjectIdentifier(screenshots.soloByObjectIdentifier)
        file.groupScreenshots = keyingByObjectIdentifier(screenshots.groupByObjectIdentifier)
        return file
    }

    // MARK: Tree

    private static func makingRootDisplayItems(
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary
    ) -> [LookinDisplayItem] {
        var rootItems: [LookinDisplayItem] = []
        var convertedViewIdentifiers: Set<String> = []

        for windowIdentifier in graph.rootIdentifiers(inGroup: vocabulary.windowGroup) {
            guard let windowItem = makingWindowItem(
                windowIdentifier: windowIdentifier,
                graph: graph,
                vocabulary: vocabulary,
                convertedViewIdentifiers: &convertedViewIdentifiers
            ) else { continue }
            rootItems.append(windowItem)
        }

        // Root views the capture recorded outside any window still belong in
        // the tree; a detached view is exactly the kind of thing someone opens
        // a capture to look at.
        for viewIdentifier in graph.rootIdentifiers(inGroup: vocabulary.viewGroup)
        where !convertedViewIdentifiers.contains(viewIdentifier) {
            guard let viewItem = makingViewItem(
                viewIdentifier: viewIdentifier,
                graph: graph,
                vocabulary: vocabulary,
                convertedViewIdentifiers: &convertedViewIdentifiers
            ) else { continue }
            rootItems.append(viewItem)
        }

        return rootItems
    }

    private static func makingWindowItem(
        windowIdentifier: String,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary,
        convertedViewIdentifiers: inout Set<String>
    ) -> LookinDisplayItem? {
        guard let windowNode = graph.node(windowIdentifier) else { return nil }

        let item = LookinDisplayItem()
        item.nodeKind = .window
        item.windowObject = makingLookinObject(for: windowNode, graph: graph)

        // A UIWindow is itself a view and owns a layer; an NSWindow is not.
        // Carrying the layer lets the window node resolve a recovered
        // screenshot, which is keyed by layer identity like every other node.
        if let layerIdentifier = windowNode.associatedIdentifiers(inGroup: GroupIdentifier.layer).first,
           let layerNode = graph.node(layerIdentifier) {
            item.layerObject = makingLookinObject(for: layerNode, graph: graph)
            applyingGeometry(from: layerNode, fallback: windowNode, to: item)
            applyingBackgroundColor(from: layerNode, to: item)
        } else {
            applyingGeometry(from: windowNode, to: item)
        }
        applyingVisibility(from: windowNode, to: item)

        if let windowControllerGroup = vocabulary.windowControllerGroup,
           let controllerIdentifier = windowNode.associatedIdentifiers(inGroup: windowControllerGroup).first,
           let controllerNode = graph.node(controllerIdentifier) {
            item.hostWindowControllerObject = makingLookinObject(for: controllerNode, graph: graph)
        }
        if let controllerIdentifier = windowNode.associatedIdentifiers(inGroup: vocabulary.viewControllerGroup).first,
           let controllerNode = graph.node(controllerIdentifier) {
            item.hostViewControllerObject = makingLookinObject(for: controllerNode, graph: graph)
        }

        // Where the window's content hangs differs by platform, and reading
        // only one of the two loses the entire hierarchy on the other. A
        // UIWindow is a view, so its subviews are its own children; an NSWindow
        // is not, so its content view is an association.
        var rootViewIdentifiers = windowNode.childIdentifiers
        rootViewIdentifiers.append(contentsOf: windowNode.associatedIdentifiers(inGroup: vocabulary.viewGroup))

        var subitems: [LookinDisplayItem] = []
        for rootViewIdentifier in rootViewIdentifiers {
            guard let viewItem = makingViewItem(
                viewIdentifier: rootViewIdentifier,
                graph: graph,
                vocabulary: vocabulary,
                convertedViewIdentifiers: &convertedViewIdentifiers
            ) else { continue }
            subitems.append(viewItem)
        }
        subitems.append(contentsOf: makingLayoutGuideItems(
            owner: windowNode, graph: graph, vocabulary: vocabulary
        ))
        item.subitems = subitems

        // A window whose frame the capture did not record still needs bounds
        // for the preview to place it; borrow the root view's.
        if item.frame == .zero, let firstChild = subitems.first {
            item.frame = firstChild.frame
            item.bounds = firstChild.bounds
        }
        return item
    }

    private static func makingViewItem(
        viewIdentifier: String,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary,
        convertedViewIdentifiers: inout Set<String>
    ) -> LookinDisplayItem? {
        // The capture is a graph, not a tree: a view reachable twice would
        // otherwise be converted twice and appear twice.
        guard convertedViewIdentifiers.insert(viewIdentifier).inserted,
              let viewNode = graph.node(viewIdentifier)
        else { return nil }

        let item = LookinDisplayItem()
        item.nodeKind = .view
        item.viewObject = makingLookinObject(for: viewNode, graph: graph)
        item.isFlipped = vocabulary.isAppKit && (viewNode.property(named: "flipped")?.value.boolValue ?? false)

        if let layerIdentifier = viewNode.associatedIdentifiers(inGroup: GroupIdentifier.layer).first,
           let layerNode = graph.node(layerIdentifier) {
            item.layerObject = makingLookinObject(for: layerNode, graph: graph)
            applyingGeometry(from: layerNode, fallback: viewNode, to: item)
            applyingBackgroundColor(from: layerNode, to: item)
        } else {
            applyingGeometry(from: viewNode, to: item)
        }
        applyingVisibility(from: viewNode, to: item)

        if let controllerIdentifier = viewNode.associatedIdentifiers(inGroup: vocabulary.viewControllerGroup).first,
           let controllerNode = graph.node(controllerIdentifier) {
            item.hostViewControllerObject = makingLookinObject(for: controllerNode, graph: graph)
        }

        var subitems: [LookinDisplayItem] = []
        for childIdentifier in viewNode.childIdentifiers {
            guard let childItem = makingViewItem(
                viewIdentifier: childIdentifier,
                graph: graph,
                vocabulary: vocabulary,
                convertedViewIdentifiers: &convertedViewIdentifiers
            ) else { continue }
            subitems.append(childItem)
        }
        subitems.append(contentsOf: makingLayoutGuideItems(
            owner: viewNode, graph: graph, vocabulary: vocabulary
        ))
        if let cellGroup = vocabulary.cellGroup {
            subitems.append(contentsOf: makingCellItems(owner: viewNode, cellGroup: cellGroup, graph: graph))
        }
        item.subitems = subitems
        return item
    }

    /// Layout guides mark out a region of their owner and carry no pixels of
    /// their own — the node model's LayoutGuide kind, riding `kindObject`.
    private static func makingLayoutGuideItems(
        owner: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary
    ) -> [LookinDisplayItem] {
        owner.associatedIdentifiers(inGroup: vocabulary.layoutGuideGroup).compactMap { guideIdentifier in
            guard let guideNode = graph.node(guideIdentifier) else { return nil }
            let item = LookinDisplayItem()
            item.nodeKind = .layoutGuide
            item.kindObject = makingLookinObject(for: guideNode, graph: graph)
            item.representsSystemManagedNode = looksSystemManaged(guideNode)
            if let layoutFrame = guideNode.property(named: "layoutFrame")?.value.numericComponents(expectedCount: 4) {
                item.frame = rect(from: layoutFrame)
                item.bounds = CGRect(origin: .zero, size: item.frame.size)
            } else {
                applyingGeometry(from: guideNode, to: item)
            }
            item.alpha = 1
            return item
        }
    }

    /// An AppKit control's cell, promoted to a first-class node by the
    /// cell-node proposal: pixelless, attributes read from the cell itself.
    private static func makingCellItems(
        owner: LKXcodeViewHierarchyNode,
        cellGroup: String,
        graph: LKXcodeViewHierarchyObjectGraph
    ) -> [LookinDisplayItem] {
        owner.associatedIdentifiers(inGroup: cellGroup).compactMap { cellIdentifier in
            guard let cellNode = graph.node(cellIdentifier) else { return nil }
            let item = LookinDisplayItem()
            item.nodeKind = .cell
            item.kindObject = makingLookinObject(for: cellNode, graph: graph)
            applyingGeometry(from: cellNode, to: item)
            item.alpha = 1
            return item
        }
    }

    /// Layout guides the system creates (safe area, layout margins, readable
    /// width) drive the inspector's toggle for hiding them.
    private static func looksSystemManaged(_ guideNode: LKXcodeViewHierarchyNode) -> Bool {
        let identifier = guideNode.property(named: "identifier")?.value.textValue ?? ""
        if identifier.hasPrefix("UIView") || identifier.hasPrefix("NSView") { return true }
        let systemIdentifiers = ["UIViewSafeAreaLayoutGuide", "UIViewLayoutMarginsGuide", "UIViewReadableContentGuide"]
        if systemIdentifiers.contains(identifier) { return true }
        let className = guideNode.className ?? ""
        return className.hasPrefix("_") || className == "NSSafeAreaLayoutGuide"
    }

    // MARK: Node fields

    private static func makingLookinObject(
        for node: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph
    ) -> LookinObject {
        let object = LookinObject()
        object.oid = objectIdentifierValue(node.objectIdentifier)
        object.memoryAddress = node.objectIdentifier
        let className = node.className ?? "NSObject"
        object.classChainList = graph.classChain(forClassName: className)
        return object
    }

    private static func applyingGeometry(
        from node: LKXcodeViewHierarchyNode,
        fallback fallbackNode: LKXcodeViewHierarchyNode? = nil,
        to item: LookinDisplayItem
    ) {
        if let frameComponents = node.property(named: "frame")?.value.numericComponents(expectedCount: 4) {
            item.frame = rect(from: frameComponents)
        } else if let fallbackComponents = fallbackNode?
            .property(named: "frame")?.value.numericComponents(expectedCount: 4) {
            item.frame = rect(from: fallbackComponents)
        }
        if let boundsComponents = node.property(named: "bounds")?.value.numericComponents(expectedCount: 4) {
            item.bounds = rect(from: boundsComponents)
        } else if let fallbackComponents = fallbackNode?
            .property(named: "bounds")?.value.numericComponents(expectedCount: 4) {
            item.bounds = rect(from: fallbackComponents)
        } else {
            item.bounds = CGRect(origin: .zero, size: item.frame.size)
        }
    }

    private static func applyingVisibility(from node: LKXcodeViewHierarchyNode, to item: LookinDisplayItem) {
        item.isHidden = node.property(named: "hidden")?.value.boolValue ?? false
        if let alpha = node.property(named: "alpha")?.value.doubleValue {
            item.alpha = Float(alpha)
        } else if let opacity = node.property(named: "opacity")?.value.doubleValue {
            item.alpha = Float(opacity)
        } else {
            item.alpha = 1
        }
    }

    /// The inspector paints this before a screenshot is available, so a node
    /// with no recovered pixels still reads as something rather than a hole.
    private static func applyingBackgroundColor(from layerNode: LKXcodeViewHierarchyNode, to item: LookinDisplayItem) {
        guard case .color(let color)? = layerNode.property(named: "backgroundColor")?.value,
              color.components.count >= 3
        else { return }
        let alpha = color.components.count >= 4 ? color.components[3] : 1
        item.backgroundColor = NSColor(
            srgbRed: color.components[0],
            green: color.components[1],
            blue: color.components[2],
            alpha: alpha
        )
    }

    private static func rect(from components: [Double]) -> CGRect {
        CGRect(x: components[0], y: components[1], width: components[2], height: components[3])
    }

    // MARK: Identity

    /// The pointer an `objectID` spells, which is what Lookin's `oid` holds.
    static func objectIdentifierValue(_ objectIdentifier: String) -> UInt {
        var text = objectIdentifier
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text = String(text.dropFirst(2)) }
        return UInt(text, radix: 16) ?? 0
    }

    private static func keyingByObjectIdentifier(_ images: [String: Data]) -> [NSNumber: Data] {
        var keyed: [NSNumber: Data] = [:]
        for (objectIdentifier, imageData) in images {
            let oid = objectIdentifierValue(objectIdentifier)
            guard oid != 0 else { continue }
            keyed[NSNumber(value: UInt64(oid))] = imageData
        }
        return keyed
    }

    // MARK: App info

    private static func makingAppInfo(
        from bundle: LKXcodeViewHierarchyBundle,
        vocabulary: Vocabulary
    ) -> LookinAppInfo {
        let appInfo = LookinAppInfo()
        appInfo.appName = bundle.metadata.runnableDisplayName ?? "Xcode Capture"
        appInfo.serverVersion = Int32(LOOKIN_SERVER_VERSION)
        // The inspector keys view-versus-layer identifier preference off this,
        // and shows the platform's own class names in its copy.
        appInfo.deviceType = vocabulary.isAppKit ? .mac : .others
        appInfo.deviceDescription = vocabulary.isAppKit ? "Mac" : "iOS"
        return appInfo
    }
}
