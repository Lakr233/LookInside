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
// The capture's tree is not the inspector's tree, and four differences matter:
//
//  1. **The top level is Xcode's, not the capture's.** The capture's root
//     groups are flat lists per class (every window, every window controller,
//     every scene, every root view). Xcode's sidebar derives its top level
//     from them and this converter replicates that derivation — see
//     `makingRootDisplayItems` — so a capture opens here with the same rows in
//     the same order as in Xcode's own View Hierarchy outline.
//  2. **A window's root view is an association, not a child.** A window object
//     carries no children at all; the view it hosts hangs off its
//     `com.apple.*.NSView`/`UIView` association. Reading only `childGroup`
//     from a window yields an empty hierarchy.
//  3. **Layers, constraints and view controllers are associations too**, and
//     they must stay out of the view tree. The inspector wants a view's layer
//     folded into the same node (as `layerObject`), not standing beside it.
//  4. **Layout guides and AppKit cells become child nodes**, because that is
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

        static let uiKitApplication = "com.apple.UIKit.UIApplication"
        static let uiKitScene = "com.apple.UIKit.UIScene"
        static let uiKitWindow = "com.apple.UIKit.UIWindow"
        static let uiKitView = "com.apple.UIKit.UIView"
        static let uiKitLayoutGuide = "com.apple.UIKit.UILayoutGuide"
        static let uiKitViewController = "com.apple.UIKit.UIViewController"

        static let appKitApplication = "com.apple.AppKit.NSApplication"
        static let appKitWindow = "com.apple.AppKit.NSWindow"
        static let appKitView = "com.apple.AppKit.NSView"
        static let appKitLayoutGuide = "com.apple.AppKit.NSLayoutGuide"
        static let appKitViewController = "com.apple.AppKit.NSViewController"
        static let appKitWindowController = "com.apple.AppKit.NSWindowController"
        static let appKitCell = "com.apple.AppKit.NSCell"
    }

    /// Class names Xcode's sidebar special-cases when deciding what to list.
    private enum ClassName {
        /// The only root views Xcode lists at the top level.
        static let touchBarView = "NSTouchBarView"
        /// Never listed, whatever its flags say.
        static let systemOverlayWindow = "_UIWindowSystemOverlayWindow"
        /// Internal, and never granted the internal-window exception.
        static let remoteKeyboardWindow = "UIRemoteKeyboardWindow"
        /// Content that earns an internal or hidden window a row anyway: the
        /// keyboard and iMessage extension windows host the user's own code.
        static let externallyRelevantControllers = ["MSMessagesAppViewController", "UIInputViewController"]
    }

    /// Which platform's naming a capture uses; everything else follows from it.
    private struct Vocabulary {
        let isAppKit: Bool
        let applicationGroup: String
        /// The group whose objects own windows — window controllers on AppKit,
        /// scenes on UIKit. Xcode lists these first, each with its windows.
        let windowOwnerGroup: String
        /// Whether an owner is a node of its own (a scene) or folds into the
        /// window's row as its controller (AppKit).
        let windowOwnerIsSceneNode: Bool
        let windowGroup: String
        let viewGroup: String
        let layoutGuideGroup: String
        let viewControllerGroup: String
        let cellGroup: String?

        static let uiKit = Vocabulary(
            isAppKit: false,
            applicationGroup: GroupIdentifier.uiKitApplication,
            windowOwnerGroup: GroupIdentifier.uiKitScene,
            windowOwnerIsSceneNode: true,
            windowGroup: GroupIdentifier.uiKitWindow,
            viewGroup: GroupIdentifier.uiKitView,
            layoutGuideGroup: GroupIdentifier.uiKitLayoutGuide,
            viewControllerGroup: GroupIdentifier.uiKitViewController,
            cellGroup: nil
        )

        static let appKit = Vocabulary(
            isAppKit: true,
            applicationGroup: GroupIdentifier.appKitApplication,
            windowOwnerGroup: GroupIdentifier.appKitWindowController,
            windowOwnerIsSceneNode: false,
            windowGroup: GroupIdentifier.appKitWindow,
            viewGroup: GroupIdentifier.appKitView,
            layoutGuideGroup: GroupIdentifier.appKitLayoutGuide,
            viewControllerGroup: GroupIdentifier.appKitViewController,
            cellGroup: GroupIdentifier.appKitCell
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

    // MARK: Top level

    /// The top level of the tree, derived the way Xcode's sidebar derives it.
    ///
    /// Xcode (DebuggerFoundation's `DBGDebugHierarchyViewObjectAdaptor`, then
    /// DebuggerUI's `DBGApplicationObject`) builds its View Hierarchy outline
    /// from the capture's root groups in this order:
    ///
    ///  1. every window owner in root-group order — window controllers on
    ///     AppKit, scenes on UIKit — each followed by the windows that name it
    ///     as their owner, in window order;
    ///  2. the windows no listed owner claims, in window order, with child
    ///     windows flattened in after the root ones;
    ///  3. root views, of which only an `NSTouchBarView` with children counts.
    ///
    /// The owner of the key window moves to the front, with the key window
    /// first among its windows. Windows that are internal or invisible are
    /// left out unless they host the user's keyboard or iMessage extension
    /// code, and a system overlay window is always left out.
    ///
    /// A root view that is not a touch bar therefore never appears — a view
    /// controller's view that is currently detached from any window, say.
    /// Xcode only shows those in its other outline mode ("View Controller
    /// Containment"), which the inspector has no counterpart for.
    private static func makingRootDisplayItems(
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary
    ) -> [LookinDisplayItem] {
        var convertedViewIdentifiers: Set<String> = []
        let keyWindowIdentifier = keyWindowIdentifier(graph: graph, vocabulary: vocabulary)
        let environment = LKXcodeViewHierarchyAttributeEnvironment(
            isAppKit: vocabulary.isAppKit,
            constraintIndex: LKXcodeViewHierarchyConstraintIndex(graph: graph),
            keyWindowIdentifier: keyWindowIdentifier
        )

        let windowIdentifiers = listedWindowIdentifiers(graph: graph, vocabulary: vocabulary)
        let listedOwnerIdentifiers = Set(graph.rootIdentifiers(inGroup: vocabulary.windowOwnerGroup))
        var windowIdentifiersByOwner: [String: [String]] = [:]
        var unownedWindowIdentifiers: [String] = []
        for windowIdentifier in windowIdentifiers {
            guard let windowNode = graph.node(windowIdentifier) else { continue }
            // Xcode only credits owners that appear in the owner root group;
            // a window whose owner the capture never listed stays unowned.
            if let ownerIdentifier = windowNode.associatedIdentifiers(inGroup: vocabulary.windowOwnerGroup).first,
               listedOwnerIdentifiers.contains(ownerIdentifier) {
                windowIdentifiersByOwner[ownerIdentifier, default: []].append(windowIdentifier)
            } else {
                unownedWindowIdentifiers.append(windowIdentifier)
            }
        }

        var ownerIdentifiers = graph.rootIdentifiers(inGroup: vocabulary.windowOwnerGroup)
        if let keyWindowIdentifier {
            if let ownerIdentifier = ownerIdentifiers.first(where: {
                windowIdentifiersByOwner[$0]?.contains(keyWindowIdentifier) == true
            }) {
                ownerIdentifiers.moveToFront(ownerIdentifier)
                windowIdentifiersByOwner[ownerIdentifier]?.moveToFront(keyWindowIdentifier)
            } else {
                unownedWindowIdentifiers.moveToFront(keyWindowIdentifier)
            }
        }

        var rootItems: [LookinDisplayItem] = []
        for ownerIdentifier in ownerIdentifiers {
            let ownedWindowIdentifiers = windowIdentifiersByOwner[ownerIdentifier] ?? []
            let windowItems = ownedWindowIdentifiers.compactMap { windowIdentifier in
                makingWindowItem(
                    windowIdentifier: windowIdentifier,
                    isKeyWindow: windowIdentifier == keyWindowIdentifier,
                    graph: graph,
                    vocabulary: vocabulary,
                    environment: environment,
                    convertedViewIdentifiers: &convertedViewIdentifiers
                )
            }
            if vocabulary.windowOwnerIsSceneNode {
                // A scene is a node even with no windows, as in a live session.
                guard let sceneNode = graph.node(ownerIdentifier) else { continue }
                rootItems.append(makingSceneItem(
                    sceneNode: sceneNode,
                    windowNodes: ownedWindowIdentifiers.compactMap(graph.node),
                    windowItems: windowItems,
                    graph: graph,
                    environment: environment
                ))
            } else {
                // A window controller is not a node here: the window row
                // carries it as its controller. One without windows has no row.
                rootItems.append(contentsOf: windowItems)
            }
        }
        for windowIdentifier in unownedWindowIdentifiers {
            guard let windowItem = makingWindowItem(
                windowIdentifier: windowIdentifier,
                isKeyWindow: windowIdentifier == keyWindowIdentifier,
                graph: graph,
                vocabulary: vocabulary,
                environment: environment,
                convertedViewIdentifiers: &convertedViewIdentifiers
            ) else { continue }
            rootItems.append(windowItem)
        }

        for viewIdentifier in graph.rootIdentifiers(inGroup: vocabulary.viewGroup)
        where !convertedViewIdentifiers.contains(viewIdentifier) {
            guard let viewNode = graph.node(viewIdentifier),
                  !viewNode.childIdentifiers.isEmpty,
                  isNode(viewNode, kindOfClassNamed: ClassName.touchBarView, graph: graph),
                  let viewItem = makingViewItem(
                      viewIdentifier: viewIdentifier,
                      superviewNode: nil,
                      graph: graph,
                      vocabulary: vocabulary,
                      environment: environment,
                      convertedViewIdentifiers: &convertedViewIdentifiers
                  )
            else { continue }
            rootItems.append(viewItem)
        }

        return rootItems
    }

    /// Every window Xcode would list, in the order it processes them: the
    /// window root group first, then child windows of those, minus the ones
    /// its skip rule excludes.
    private static func listedWindowIdentifiers(
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary
    ) -> [String] {
        let rootWindowIdentifiers = graph.rootIdentifiers(inGroup: vocabulary.windowGroup)
        var childWindowIdentifiers: [String] = []
        for rootWindowIdentifier in rootWindowIdentifiers {
            appendingChildWindowIdentifiers(
                of: rootWindowIdentifier, graph: graph, vocabulary: vocabulary, into: &childWindowIdentifiers
            )
        }

        var seen: Set<String> = []
        return (rootWindowIdentifiers + childWindowIdentifiers).filter { windowIdentifier in
            guard seen.insert(windowIdentifier).inserted, let windowNode = graph.node(windowIdentifier) else {
                return false
            }
            return !shouldSkipWindow(windowNode, graph: graph, vocabulary: vocabulary)
        }
    }

    /// An NSWindow's `childGroup` holds its child windows (a UIWindow's holds
    /// its subviews, which are not windows and are left alone here).
    private static func appendingChildWindowIdentifiers(
        of windowIdentifier: String,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary,
        into childWindowIdentifiers: inout [String]
    ) {
        guard let windowNode = graph.node(windowIdentifier) else { return }
        for childIdentifier in windowNode.childIdentifiers
        where graph.node(childIdentifier)?.groupingIdentifier == vocabulary.windowGroup {
            childWindowIdentifiers.append(childIdentifier)
            appendingChildWindowIdentifiers(
                of: childIdentifier, graph: graph, vocabulary: vocabulary, into: &childWindowIdentifiers
            )
        }
    }

    /// Xcode's rule for leaving a window out of the sidebar. The flag pair is
    /// only recorded by the UIKit agent; AppKit captures carry neither, so no
    /// AppKit window is ever skipped on their account.
    private static func shouldSkipWindow(
        _ windowNode: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary
    ) -> Bool {
        if isNode(windowNode, kindOfClassNamed: ClassName.systemOverlayWindow, graph: graph) { return true }
        guard let isInternal = windowNode.property(named: "internal")?.value.boolValue,
              let isVisible = windowNode.property(named: "visible")?.value.boolValue,
              isInternal || !isVisible
        else { return false }
        return !hostsExternallyRelevantContent(windowNode, graph: graph, vocabulary: vocabulary)
    }

    /// Whether an internal or hidden window still deserves a row: the
    /// keyboard and iMessage extension windows are the system's, but the view
    /// controllers inside them are the user's.
    private static func hostsExternallyRelevantContent(
        _ windowNode: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary
    ) -> Bool {
        if isNode(windowNode, kindOfClassNamed: ClassName.remoteKeyboardWindow, graph: graph) { return false }
        var pendingControllerIdentifiers = windowNode.associatedIdentifiers(inGroup: vocabulary.viewControllerGroup)
        var visited: Set<String> = []
        while !pendingControllerIdentifiers.isEmpty {
            let controllerIdentifier = pendingControllerIdentifiers.removeFirst()
            guard visited.insert(controllerIdentifier).inserted,
                  let controllerNode = graph.node(controllerIdentifier)
            else { continue }
            if ClassName.externallyRelevantControllers.contains(where: {
                isNode(controllerNode, kindOfClassNamed: $0, graph: graph)
            }) {
                return true
            }
            pendingControllerIdentifiers.append(contentsOf: controllerNode.childIdentifiers)
        }
        return false
    }

    /// The window the application object names as key, if the capture
    /// recorded one. Xcode reads the pointer off the application, not the
    /// windows' own flags.
    private static func keyWindowIdentifier(
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary
    ) -> String? {
        guard let applicationIdentifier = graph.rootIdentifiers(inGroup: vocabulary.applicationGroup).first,
              let keyWindowText = graph.node(applicationIdentifier)?.property(named: "keyWindow")?.value.textValue
        else { return nil }
        let keyWindowValue = objectIdentifierValue(keyWindowText)
        guard keyWindowValue != 0 else { return nil }
        return graph.rootIdentifiers(inGroup: vocabulary.windowGroup)
            .first { objectIdentifierValue($0) == keyWindowValue }
            ?? graph.nodesByIdentifier.keys.first { objectIdentifierValue($0) == keyWindowValue }
    }

    // MARK: Tree

    /// A UIKit scene, the node a live session puts above its windows.
    private static func makingSceneItem(
        sceneNode: LKXcodeViewHierarchyNode,
        windowNodes: [LKXcodeViewHierarchyNode],
        windowItems: [LookinDisplayItem],
        graph: LKXcodeViewHierarchyObjectGraph,
        environment: LKXcodeViewHierarchyAttributeEnvironment
    ) -> LookinDisplayItem {
        let item = makingDisplayItem(kind: .windowScene)
        item.windowObject = makingLookinObject(for: sceneNode, graph: graph)
        item.alpha = 1
        item.customDisplayTitle = sceneDisplayTitle(for: sceneNode)
        item.representedAsKeyWindow = windowItems.contains { $0.representedAsKeyWindow }
        var context = LKXcodeViewHierarchyAttributeContext(role: .windowScene, environment: environment)
        context.sceneWindowNodes = windowNodes
        item.attributesGroupList = LKXcodeViewHierarchyAttributes.makingGroups(
            for: sceneNode, layerNode: nil, graph: graph, context: context
        )
        item.subitems = windowItems
        return item
    }

    /// The server's title shape for a scene: class, title, activation state.
    private static func sceneDisplayTitle(for sceneNode: LKXcodeViewHierarchyNode) -> String {
        var title = sceneNode.className ?? "UIWindowScene"
        if let sceneTitle = sceneNode.property(named: "title")?.value.textValue, !sceneTitle.isEmpty {
            title += " – \(sceneTitle)"
        }
        if let activationState = sceneNode.property(named: "activationState")?.value.doubleValue {
            let stateDescription: String
            switch Int(activationState) {
            case -1: stateDescription = "Unattached"
            case 0: stateDescription = "Foreground Active"
            case 1: stateDescription = "Foreground Inactive"
            case 2: stateDescription = "Background"
            default: stateDescription = "Unknown"
            }
            title += " (\(stateDescription))"
        }
        return title
    }

    private static func makingWindowItem(
        windowIdentifier: String,
        isKeyWindow: Bool,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary,
        environment: LKXcodeViewHierarchyAttributeEnvironment,
        convertedViewIdentifiers: inout Set<String>
    ) -> LookinDisplayItem? {
        guard let windowNode = graph.node(windowIdentifier) else { return nil }

        let item = makingDisplayItem(kind: .window)
        item.windowObject = makingLookinObject(for: windowNode, graph: graph)
        item.representedAsKeyWindow = isKeyWindow
        // A UIWindow is a view and gets a view's cards; an NSWindow is not.
        var context = LKXcodeViewHierarchyAttributeContext(
            role: vocabulary.isAppKit ? .window : .view, environment: environment
        )

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

        if !vocabulary.windowOwnerIsSceneNode,
           let controllerIdentifier = windowNode.associatedIdentifiers(inGroup: vocabulary.windowOwnerGroup).first,
           let controllerNode = graph.node(controllerIdentifier) {
            item.hostWindowControllerObject = makingLookinObject(for: controllerNode, graph: graph)
            context.windowControllerNode = controllerNode
        }
        // The window's root view controller marks the row, as before; the
        // cards leave it out, since a window is not that controller's view
        // and a live session's Class and Relation cards do not list it.
        if let controllerIdentifier = windowNode.associatedIdentifiers(inGroup: vocabulary.viewControllerGroup).first,
           let controllerNode = graph.node(controllerIdentifier) {
            item.hostViewControllerObject = makingLookinObject(for: controllerNode, graph: graph)
        }

        // Where the window's content hangs differs by platform, and reading
        // only one of the two loses the entire hierarchy on the other. A
        // UIWindow is a view, so its subviews are its own children; an NSWindow
        // is not, so its content view is an association — and its children,
        // when it has any, are child windows, which the top level lists.
        var rootViewIdentifiers = windowNode.childIdentifiers.filter {
            graph.node($0)?.groupingIdentifier != vocabulary.windowGroup
        }
        rootViewIdentifiers.append(contentsOf: windowNode.associatedIdentifiers(inGroup: vocabulary.viewGroup))

        var subitems: [LookinDisplayItem] = []
        for rootViewIdentifier in rootViewIdentifiers {
            guard let viewItem = makingViewItem(
                viewIdentifier: rootViewIdentifier,
                superviewNode: windowNode,
                graph: graph,
                vocabulary: vocabulary,
                environment: environment,
                convertedViewIdentifiers: &convertedViewIdentifiers
            ) else { continue }
            subitems.append(viewItem)
        }
        subitems.append(contentsOf: makingLayoutGuideItems(
            owner: windowNode, graph: graph, vocabulary: vocabulary, environment: environment
        ))
        item.subitems = subitems
        item.attributesGroupList = LKXcodeViewHierarchyAttributes.makingGroups(
            for: windowNode, layerNode: associatedLayerNode(of: windowNode, graph: graph), graph: graph, context: context
        )

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
        superviewNode: LKXcodeViewHierarchyNode?,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary,
        environment: LKXcodeViewHierarchyAttributeEnvironment,
        convertedViewIdentifiers: inout Set<String>
    ) -> LookinDisplayItem? {
        // The capture is a graph, not a tree: a view reachable twice would
        // otherwise be converted twice and appear twice.
        guard convertedViewIdentifiers.insert(viewIdentifier).inserted,
              let viewNode = graph.node(viewIdentifier)
        else { return nil }

        let item = makingDisplayItem(kind: .view)
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

        var context = LKXcodeViewHierarchyAttributeContext(role: .view, environment: environment)
        context.superviewNode = superviewNode
        if let controllerIdentifier = viewNode.associatedIdentifiers(inGroup: vocabulary.viewControllerGroup).first,
           let controllerNode = graph.node(controllerIdentifier) {
            item.hostViewControllerObject = makingLookinObject(for: controllerNode, graph: graph)
            context.viewControllerNode = controllerNode
        }
        item.attributesGroupList = LKXcodeViewHierarchyAttributes.makingGroups(
            for: viewNode, layerNode: associatedLayerNode(of: viewNode, graph: graph), graph: graph, context: context
        )

        var subitems: [LookinDisplayItem] = []
        for childIdentifier in viewNode.childIdentifiers {
            guard let childItem = makingViewItem(
                viewIdentifier: childIdentifier,
                superviewNode: viewNode,
                graph: graph,
                vocabulary: vocabulary,
                environment: environment,
                convertedViewIdentifiers: &convertedViewIdentifiers
            ) else { continue }
            subitems.append(childItem)
        }
        subitems.append(contentsOf: makingLayoutGuideItems(
            owner: viewNode, graph: graph, vocabulary: vocabulary, environment: environment
        ))
        if let cellGroup = vocabulary.cellGroup {
            subitems.append(contentsOf: makingCellItems(
                owner: viewNode, cellGroup: cellGroup, graph: graph, environment: environment
            ))
        }
        item.subitems = subitems
        return item
    }

    /// Layout guides mark out a region of their owner and carry no pixels of
    /// their own — the node model's LayoutGuide kind, riding `kindObject`.
    private static func makingLayoutGuideItems(
        owner: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph,
        vocabulary: Vocabulary,
        environment: LKXcodeViewHierarchyAttributeEnvironment
    ) -> [LookinDisplayItem] {
        var context = LKXcodeViewHierarchyAttributeContext(role: .layoutGuide, environment: environment)
        context.ownerNode = owner
        return owner.associatedIdentifiers(inGroup: vocabulary.layoutGuideGroup).compactMap { guideIdentifier in
            guard let guideNode = graph.node(guideIdentifier) else { return nil }
            let item = makingDisplayItem(kind: .layoutGuide)
            item.kindObject = makingLookinObject(for: guideNode, graph: graph)
            item.representsSystemManagedNode = looksSystemManaged(guideNode)
            if let layoutFrame = guideNode.property(named: "layoutFrame")?.value.numericComponents(expectedCount: 4) {
                item.frame = rect(from: layoutFrame)
                item.bounds = CGRect(origin: .zero, size: item.frame.size)
            } else {
                applyingGeometry(from: guideNode, to: item)
            }
            item.alpha = 1
            item.attributesGroupList = LKXcodeViewHierarchyAttributes.makingGroups(
                for: guideNode, layerNode: nil, graph: graph, context: context
            )
            return item
        }
    }

    /// An AppKit control's cell, promoted to a first-class node by the
    /// cell-node proposal: pixelless, attributes read from the cell itself.
    private static func makingCellItems(
        owner: LKXcodeViewHierarchyNode,
        cellGroup: String,
        graph: LKXcodeViewHierarchyObjectGraph,
        environment: LKXcodeViewHierarchyAttributeEnvironment
    ) -> [LookinDisplayItem] {
        var context = LKXcodeViewHierarchyAttributeContext(role: .cell, environment: environment)
        context.ownerNode = owner
        return owner.associatedIdentifiers(inGroup: cellGroup).compactMap { cellIdentifier in
            guard let cellNode = graph.node(cellIdentifier) else { return nil }
            let item = makingDisplayItem(kind: .cell)
            item.kindObject = makingLookinObject(for: cellNode, graph: graph)
            applyingGeometry(from: cellNode, to: item)
            item.alpha = 1
            item.attributesGroupList = LKXcodeViewHierarchyAttributes.makingGroups(
                for: cellNode, layerNode: nil, graph: graph, context: context
            )
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

    /// Every node starts here. `shouldCaptureImage` is opted into explicitly:
    /// its Objective-C default is NO, and the host reads NO as "the user's
    /// config excluded this layer", marking the node and its whole subtree
    /// `noPreview` — the preview then receives nothing (node-model-internals,
    /// trap 1). The server sets the flag per kind and the archive decoder
    /// defaults an absent key to YES; an in-memory producer gets neither.
    private static func makingDisplayItem(kind: LookinDisplayItemNodeKind) -> LookinDisplayItem {
        let item = LookinDisplayItem()
        item.nodeKind = kind
        item.shouldCaptureImage = true
        return item
    }

    /// Xcode's `isKindOfTypeWithName:` — the class or any of its ancestors.
    private static func isNode(
        _ node: LKXcodeViewHierarchyNode,
        kindOfClassNamed className: String,
        graph: LKXcodeViewHierarchyObjectGraph
    ) -> Bool {
        guard let nodeClassName = node.className else { return false }
        return graph.classChain(forClassName: nodeClassName).contains(className)
    }

    private static func associatedLayerNode(
        of node: LKXcodeViewHierarchyNode,
        graph: LKXcodeViewHierarchyObjectGraph
    ) -> LKXcodeViewHierarchyNode? {
        guard let layerIdentifier = node.associatedIdentifiers(inGroup: GroupIdentifier.layer).first else {
            return nil
        }
        return graph.node(layerIdentifier)
    }

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

extension LKXcodeViewHierarchyConversionError: LocalizedError {
    var errorDescription: String? { description }
}

private extension Array where Element: Equatable {
    /// Moves `element` to index 0 when present; leaves the order otherwise.
    mutating func moveToFront(_ element: Element) {
        guard let index = firstIndex(of: element), index != 0 else { return }
        remove(at: index)
        insert(element, at: 0)
    }
}
