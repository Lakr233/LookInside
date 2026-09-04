// LKXcodeViewHierarchyPixelRecovery.swift
//
// Renders the layer trees recovered from a `.viewhierarchy` capture into the
// per-node screenshots the inspector displays.
//
// Output shape deliberately mirrors a `.lookin` archive — encoded image data
// keyed by object identifier, one solo image and one group image per node —
// so the conversion layer can hand it to the same read path that already
// serves `.lookin` documents.
//
// Orientation is the detail that decides whether the result is usable, and
// two facts about Core Animation govern it:
//
//   * `isGeometryFlipped` is relative to the superlayer. Marking a layer flips
//     the axis for its sublayers; marking a sublayer as well flips it back.
//     AppKit already writes the flag that way for flipped views, so an AppKit
//     archive is self-describing. A UIKit archive is y-down at every level and
//     carries no flags (the archive's own `geometryFlipped` says so), so the
//     root alone is marked and the whole tree inherits the y-down axis.
//     Marking every layer, as this once did, flips depth two upside down again.
//   * The flag is ignored on whichever layer is the root of a render. A layer
//     whose cumulative flip is odd — `contentsAreFlipped` — comes out mirrored
//     when rendered on its own, so its context is flipped to make its image
//     match what it looks like inside the tree. This is the rule the server
//     applies when it screenshots a live macOS layer, and the one Xcode's own
//     view debugger uses.
//
// Both halves are needed. Without the root flag a UIKit tree's sublayers stack
// in reverse; without the context flip every flipped subtree — an
// NSOutlineView, an NSTextView, a UIKit screen — reads mirrored, which is how
// an imported Xcode window once came back with its navigator upside down while
// the window as a whole rendered fine.

import AppKit
import Foundation
import QuartzCore

struct LKXcodeViewHierarchyScreenshots {
    /// PNG data for each node rendered without its sublayers.
    let soloByObjectIdentifier: [String: Data]
    /// PNG data for each node rendered with its whole subtree.
    let groupByObjectIdentifier: [String: Data]
    /// PNG data for each node rendered with its subtree minus the subtrees of
    /// the layers that back a view: what a layer node shows once the views
    /// beneath it render on nodes of their own (the server's
    /// `lks_groupScreenshotExcludingHostedSubtreesWithLowQuality:`). Present
    /// only where a hosted layer exists below the node; elsewhere the group
    /// image already is that picture.
    var groupExcludingHostedViewsByObjectIdentifier: [String: Data] = [:]
    /// Layer archives that failed to decode; the nodes below them have no pixels.
    let failedArchiveIdentifiers: [String]
}

enum LKXcodeViewHierarchyPixelRecovery {
    /// Upper bound on the pixels of one rendered image.
    ///
    /// A capture holds thousands of layers; without a cap the import of a
    /// large window allocates gigabytes. Anything larger is rendered at a
    /// reduced scale rather than skipped, so the preview stays complete but
    /// coarser. Sixteen megapixels is the budget Xcode's own view debugger
    /// allows a layer image (it refuses anything bigger outright); a
    /// full-screen retina layer is about thirteen.
    static let maximumRenderedPixelCount = 16_000_000

    /// Upper bound on either side of one rendered image, in pixels.
    ///
    /// The preview puts every image on a SceneKit material, and a texture
    /// longer than this cannot be uploaded — the host asserts the same bound
    /// (`LookinNodeImageMaxLengthInPx`). A layer taller than this at its own
    /// scale is rendered coarser to fit, never dropped: a folded node's whole
    /// subtree lives in this one image, so a missing image is a hole.
    static let maximumRenderedEdgeLength: CGFloat = 16384

    /// Layers below this size carry no useful preview and are common enough
    /// (separators, hairlines, zero-size containers) to be worth skipping.
    static let minimumRenderedEdgeLength: CGFloat = 1

    /// Renders every node the capture has pixels for.
    ///
    /// Must be called from a single thread; it mutates the decoded layer trees
    /// while rendering (detaching sublayers for the solo pass) and restores
    /// them before returning.
    ///
    /// `isCancelled` is polled once per layer. When it answers true the render
    /// stops and nothing is returned: a partial set of images would read as
    /// missing pixels rather than as an abandoned import.
    static func recovering(
        from graph: LKXcodeViewHierarchyObjectGraph,
        isCancelled: () -> Bool = { false }
    ) -> LKXcodeViewHierarchyScreenshots {
        let (trees, failedIdentifiers) = LKXcodeViewHierarchyLayerArchive.decodingLayerTrees(in: graph)
        let alignment = LKXcodeViewHierarchyLayerAlignment.aligning(trees: trees, graph: graph)
        let topology = LKXcodeViewHierarchyLayerTopology(graph: graph)

        for tree in trees where tree.isGeometryFlipped {
            // A y-down capture: the root carries the axis and the subtree
            // inherits it. The context flip in renderingPNG is the other half.
            tree.rootLayer.isGeometryFlipped = true
        }

        var soloByObjectIdentifier: [String: Data] = [:]
        var groupByObjectIdentifier: [String: Data] = [:]
        var groupExcludingHostedViewsByObjectIdentifier: [String: Data] = [:]

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        for (objectIdentifier, layer) in alignment {
            if isCancelled() {
                return LKXcodeViewHierarchyScreenshots(
                    soloByObjectIdentifier: [:], groupByObjectIdentifier: [:], failedArchiveIdentifiers: failedIdentifiers
                )
            }
            let isFlipped = layer.contentsAreFlipped()
            let hasSublayers = !(layer.sublayers?.isEmpty ?? true)
            // A layer that paints nothing but its background colour needs no
            // image of its own: the inspector fills a node that has no image
            // with the node's background colour, which is the same picture
            // for a fraction of the memory and import time. Its subtree
            // still needs the group image.
            let paintsOnlyItsBackground = representsPlainColorFill(layer)
            if !paintsOnlyItsBackground || hasSublayers,
               let groupImage = renderingPNG(of: layer, includingSublayers: true, isFlipped: isFlipped) {
                groupByObjectIdentifier[objectIdentifier] = groupImage
            }
            // The views beneath a layer node render on planes of their own;
            // a layer node's group therefore leaves their subtrees out.
            let hostedDescendants = topology.hostedDescendantIdentifiers(of: objectIdentifier, graph: graph)
                .compactMap { alignment[$0] }
            if !hostedDescendants.isEmpty,
               let excludingImage = renderingPNG(
                   of: layer, includingSublayers: true, hiding: hostedDescendants, isFlipped: isFlipped
               ) {
                groupExcludingHostedViewsByObjectIdentifier[objectIdentifier] = excludingImage
            }
            // A node with no sublayers renders identically either way; storing
            // the second copy would double the memory for no visible gain.
            guard hasSublayers, !paintsOnlyItsBackground else { continue }
            if let soloImage = renderingPNG(of: layer, includingSublayers: false, isFlipped: isFlipped) {
                soloByObjectIdentifier[objectIdentifier] = soloImage
            }
        }

        return LKXcodeViewHierarchyScreenshots(
            soloByObjectIdentifier: soloByObjectIdentifier,
            groupByObjectIdentifier: groupByObjectIdentifier,
            groupExcludingHostedViewsByObjectIdentifier: groupExcludingHostedViewsByObjectIdentifier,
            failedArchiveIdentifiers: failedIdentifiers
        )
    }

    // MARK: - Rendering

    /// `hiddenLayers` are hidden for the duration of the render and restored
    /// afterwards; they must be descendants of `layer`.
    static func renderingPNG(
        of layer: CALayer,
        includingSublayers: Bool,
        hiding hiddenLayers: [CALayer] = [],
        isFlipped: Bool
    ) -> Data? {
        let bounds = layer.bounds
        guard bounds.width >= minimumRenderedEdgeLength, bounds.height >= minimumRenderedEdgeLength,
              bounds.width.isFinite, bounds.height.isFinite
        else { return nil }

        let scale = renderingScale(for: layer)
        // Rounded down so a layer sitting exactly at a cap cannot creep past
        // it by a row of pixels.
        let pixelWidth = Int((bounds.width * scale).rounded(.down))
        let pixelHeight = Int((bounds.height * scale).rounded(.down))
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceSRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        var detachedSublayers: [CALayer]?
        if !includingSublayers, let existingSublayers = layer.sublayers, !existingSublayers.isEmpty {
            detachedSublayers = existingSublayers
            layer.sublayers = nil
        }
        let layersHiddenForRender = hiddenLayers.filter { !$0.isHidden }
        for hiddenLayer in layersHiddenForRender { hiddenLayer.isHidden = true }
        defer {
            if let detachedSublayers { layer.sublayers = detachedSublayers }
            for hiddenLayer in layersHiddenForRender { hiddenLayer.isHidden = false }
        }

        context.scaleBy(x: scale, y: scale)
        if isFlipped {
            // The layer's cumulative flip is odd: mirror the context so the
            // image matches how the layer looks inside its tree.
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        layer.render(in: context)

        guard let renderedImage = context.makeImage(), containsVisiblePixels(context) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: renderedImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Scale that keeps the layer's own resolution without exceeding either
    /// cap: first the longest side, then the pixel budget.
    static func renderingScale(for layer: CALayer) -> CGFloat {
        let bounds = layer.bounds
        var scale = layer.contentsScale > 0 ? layer.contentsScale : 1
        let longestSide = max(bounds.width, bounds.height)
        if longestSide * scale > maximumRenderedEdgeLength {
            scale = maximumRenderedEdgeLength / longestSide
        }
        let pixelCount = bounds.width * scale * bounds.height * scale
        if pixelCount > CGFloat(maximumRenderedPixelCount) {
            scale *= (CGFloat(maximumRenderedPixelCount) / pixelCount).squareRoot()
        }
        return max(scale, 0.1)
    }

    /// Xcode's `-[DBGViewSurface _needsImageSnapshot]`, negated: a plain
    /// CALayer whose only drawing is a solid background colour. Anything that
    /// draws more — contents, a mask, a border, rounded corners, a shadow, a
    /// filter, a subclass with its own drawing, a pattern colour — needs a
    /// real render.
    static func representsPlainColorFill(_ layer: CALayer) -> Bool {
        guard type(of: layer) == CALayer.self,
              layer.contents == nil,
              layer.mask == nil,
              layer.borderWidth <= 0,
              layer.cornerRadius <= 0,
              layer.shadowOpacity <= 0,
              layer.compositingFilter == nil,
              layer.filters?.isEmpty ?? true,
              layer.backgroundFilters?.isEmpty ?? true
        else { return false }
        if let backgroundColor = layer.backgroundColor,
           let colorSpace = backgroundColor.colorSpace,
           colorSpace.model == .pattern {
            return false
        }
        return true
    }

    /// True when anything was drawn.
    ///
    /// Most layers in a capture are transparent containers. Storing their empty
    /// images would multiply the document's memory for nothing — the inspector
    /// already falls back to the node's background colour when an image is
    /// absent.
    private static func containsVisiblePixels(_ context: CGContext) -> Bool {
        guard let pixels = context.data else { return false }
        let width = context.width
        let height = context.height
        let bytesPerRow = context.bytesPerRow
        let buffer = pixels.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)

        for row in 0..<height {
            let rowStart = row * bytesPerRow
            for column in 0..<width where buffer[rowStart + column * 4 + 3] != 0 {
                return true
            }
        }
        return false
    }

    private static func CGColorSpaceSRGB() -> CGColorSpace {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }
}
