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
// Orientation is the detail that decides whether the result is usable, and it
// needs two corrections rather than one. The archive records a
// `geometryFlipped` flag: UIKit captures set it, AppKit captures do not. An
// AppKit tree renders correctly with no correction at all. A UIKit tree is
// y-down, and Core Animation on macOS reads the decoded layers as y-up, which
// spoils two things independently:
//
//   * sublayer *positions* come out in reverse order, and
//   * layer *contents* would come out mirrored if the context were simply
//     flipped to compensate.
//
// Correcting only one is worse than correcting neither, and both failures look
// like "the flip is wrong" without saying which. Measured on a real capture of
// a music player screen:
//
//     no correction              art at the bottom, text readable
//     flipped context only       art at the top, every glyph mirrored
//     geometryFlipped only       art at the bottom, every glyph mirrored
//     both (what this does)      correct
//
// So: set `isGeometryFlipped` on every layer of a y-down tree, which restores
// each level's sublayer ordering and mirrors the contents, then flip the
// context, which mirrors everything back. Setting the flag on the root alone
// does nothing — the archived UIKit layers do not carry the property, so every
// level has to be told.

import AppKit
import Foundation
import QuartzCore

struct LKXcodeViewHierarchyScreenshots {
    /// PNG data for each node rendered without its sublayers.
    let soloByObjectIdentifier: [String: Data]
    /// PNG data for each node rendered with its whole subtree.
    let groupByObjectIdentifier: [String: Data]
    /// Layer archives that failed to decode; the nodes below them have no pixels.
    let failedArchiveIdentifiers: [String]
}

enum LKXcodeViewHierarchyPixelRecovery {
    /// Upper bound on the pixels of one rendered image.
    ///
    /// A full-screen retina layer is already ~13 megapixels, and a capture
    /// holds thousands of layers; without a cap the import of a large window
    /// allocates gigabytes. Anything larger is rendered at a reduced scale
    /// rather than skipped, so the preview stays complete but coarser.
    static let maximumRenderedPixelCount = 4_000_000

    /// Layers below this size carry no useful preview and are common enough
    /// (separators, hairlines, zero-size containers) to be worth skipping.
    static let minimumRenderedEdgeLength: CGFloat = 1

    /// Renders every node the capture has pixels for.
    ///
    /// Must be called from a single thread; it mutates the decoded layer trees
    /// while rendering (detaching sublayers for the solo pass) and restores
    /// them before returning.
    static func recovering(from graph: LKXcodeViewHierarchyObjectGraph) -> LKXcodeViewHierarchyScreenshots {
        let (trees, failedIdentifiers) = LKXcodeViewHierarchyLayerArchive.decodingLayerTrees(in: graph)
        let alignment = LKXcodeViewHierarchyLayerAlignment.aligning(trees: trees, graph: graph)

        var flippedRootIdentifiers: Set<String> = []
        for tree in trees where tree.isGeometryFlipped {
            flippedRootIdentifiers.insert(tree.rootObjectIdentifier)
            // Half of the orientation fix; the context flip in renderingPNG is
            // the other half, and neither works alone.
            applyingGeometryFlip(to: tree.rootLayer)
        }
        let flippedIdentifiers = identifiersUnderFlippedRoots(
            flippedRootIdentifiers: flippedRootIdentifiers, alignment: alignment, graph: graph
        )

        var soloByObjectIdentifier: [String: Data] = [:]
        var groupByObjectIdentifier: [String: Data] = [:]

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        for (objectIdentifier, layer) in alignment {
            let isFlipped = flippedIdentifiers.contains(objectIdentifier)
            if let groupImage = renderingPNG(of: layer, includingSublayers: true, isFlipped: isFlipped) {
                groupByObjectIdentifier[objectIdentifier] = groupImage
            }
            // A node with no sublayers renders identically either way; storing
            // the second copy would double the memory for no visible gain.
            guard let sublayers = layer.sublayers, !sublayers.isEmpty else { continue }
            if let soloImage = renderingPNG(of: layer, includingSublayers: false, isFlipped: isFlipped) {
                soloByObjectIdentifier[objectIdentifier] = soloImage
            }
        }

        return LKXcodeViewHierarchyScreenshots(
            soloByObjectIdentifier: soloByObjectIdentifier,
            groupByObjectIdentifier: groupByObjectIdentifier,
            failedArchiveIdentifiers: failedIdentifiers
        )
    }

    /// Marks a y-down tree as such at every level, so Core Animation orders
    /// each layer's sublayers the way the capturing platform did.
    private static func applyingGeometryFlip(to layer: CALayer) {
        layer.isGeometryFlipped = true
        for sublayer in layer.sublayers ?? [] { applyingGeometryFlip(to: sublayer) }
    }

    /// Every aligned identifier that sits inside a geometry-flipped tree.
    private static func identifiersUnderFlippedRoots(
        flippedRootIdentifiers: Set<String>,
        alignment: [String: CALayer],
        graph: LKXcodeViewHierarchyObjectGraph
    ) -> Set<String> {
        var flipped: Set<String> = []
        var pending = Array(flippedRootIdentifiers)
        while let objectIdentifier = pending.popLast() {
            guard alignment[objectIdentifier] != nil, flipped.insert(objectIdentifier).inserted else { continue }
            pending.append(contentsOf: graph.node(objectIdentifier)?.childIdentifiers ?? [])
        }
        return flipped
    }

    // MARK: - Rendering

    static func renderingPNG(of layer: CALayer, includingSublayers: Bool, isFlipped: Bool) -> Data? {
        let bounds = layer.bounds
        guard bounds.width >= minimumRenderedEdgeLength, bounds.height >= minimumRenderedEdgeLength,
              bounds.width.isFinite, bounds.height.isFinite
        else { return nil }

        let scale = renderingScale(for: layer)
        let pixelWidth = Int((bounds.width * scale).rounded())
        let pixelHeight = Int((bounds.height * scale).rounded())
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
        defer {
            if let detachedSublayers { layer.sublayers = detachedSublayers }
        }

        context.scaleBy(x: scale, y: scale)
        if isFlipped {
            // Undo the bottom-left origin so top-left-origin content lands upright.
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        layer.render(in: context)

        guard let renderedImage = context.makeImage(), containsVisiblePixels(context) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: renderedImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Scale that keeps the layer's own resolution without exceeding the cap.
    private static func renderingScale(for layer: CALayer) -> CGFloat {
        let bounds = layer.bounds
        let preferredScale = layer.contentsScale > 0 ? layer.contentsScale : 1
        let preferredPixelCount = bounds.width * preferredScale * bounds.height * preferredScale
        guard preferredPixelCount > CGFloat(maximumRenderedPixelCount) else { return preferredScale }
        let reduction = (CGFloat(maximumRenderedPixelCount) / preferredPixelCount).squareRoot()
        return max(preferredScale * reduction, 0.1)
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
