import AppKit
import Foundation
import QuartzCore

/// Coverage for recovering pixels from a capture's layer archives.
///
/// The orientation cases are the reason this file exists. A UIKit capture is
/// y-down and Core Animation on macOS reads it as y-up, which needs two
/// separate corrections — marking every layer geometry-flipped, and flipping
/// the render context. Applying one without the other produces an image that
/// is wrong in a way no assertion on file size or pixel count would catch:
/// either the subviews come out in reverse order, or every glyph is mirrored.
/// The tests below place a marker in a known corner and check where it lands,
/// which is the smallest thing that can tell those apart.
@main
struct LKXcodeViewHierarchyPixelRecoveryTests {
    static func main() {
        testUnflippedTreeKeepsSublayerPosition()
        testFlippedTreeInvertsSublayerPosition()
        testRecoveryAppliesTheGeometryFlipItself()
        testEmptyLayerProducesNoImage()
        testZeroSizedLayerProducesNoImage()
        testLargeLayerIsScaledWithinTheCap()
        testArchiveRoundTripsThroughDecoder()
        testMalformedArchiveIsRejected()
        print("Xcode view hierarchy pixel recovery tests passed")
    }

    // MARK: - Orientation

    /// AppKit captures are already y-up and need no correction: a band pinned
    /// at the coordinate origin occupies the *bottom* of the image, with its
    /// content the right way up.
    private static func testUnflippedTreeKeepsSublayerPosition() {
        guard let rendered = renderedFixture(applyingGeometryFlip: false, flippingContext: false) else {
            fail("unflipped render produced no image")
        }
        expect(rendered.bandIsAtBottom, "a y-up tree should put the band at the bottom")
        expect(rendered.contentIsUpright, "a y-up tree should not mirror the band's content")
    }

    /// UIKit captures are y-down, and correcting them takes both halves.
    ///
    /// The two assertions here are what tell the halves apart. Dropping the
    /// context flip leaves the band at the bottom; dropping the geometry flag
    /// leaves the band in the right place but mirrors its content, which on a
    /// real capture means every glyph reads backwards.
    private static func testFlippedTreeInvertsSublayerPosition() {
        guard let rendered = renderedFixture(applyingGeometryFlip: true, flippingContext: true) else {
            fail("flipped render produced no image")
        }
        expect(rendered.bandIsAtTop, "a y-down tree should put the band at the top")
        expect(rendered.contentIsUpright, "a y-down tree should not mirror the band's content")
    }

    /// The two previous cases prepare the tree themselves, so they would still
    /// pass if the recovery entry point stopped marking y-down trees. This one
    /// goes through `recovering(from:)` with nothing but a capture, which is
    /// the only way to catch that half going missing.
    private static func testRecoveryAppliesTheGeometryFlipItself() {
        guard let archiveData = archiveData(rootLayer: orientationFixture(), geometryFlipped: true) else {
            fail("could not build the archive fixture")
        }
        let builder = LKXcodeViewHierarchyObjectGraphBuilder()
        builder.ingesting(response: [
            "version": NSNumber(value: 2),
            "topLevelGroups": [
                "com.apple.QuartzCore.CALayer": [
                    "groupingID": "com.apple.QuartzCore.CALayer",
                    "debugHierarchyObjects": [["objectID": "0x1", "className": "CALayer"]],
                ],
            ],
            "topLevelPropertyDescriptions": [
                "0x1.encodedPresentationLayer": [
                    "propertyName": "encodedPresentationLayer",
                    "propertyFormat": "public.data",
                    "propertyValue": archiveData.base64EncodedString(),
                    "fetchStatus": NSNumber(value: 4),
                ],
            ],
        ])

        let screenshots = LKXcodeViewHierarchyPixelRecovery.recovering(from: builder.build())
        guard let groupImage = screenshots.groupByObjectIdentifier["0x1"] else {
            fail("recovery produced no image for the captured layer")
        }
        guard let bitmap = NSBitmapImageRep(data: groupImage) else { fail("recovered data was not a bitmap") }
        let rendered = measuring(bitmap)
        expect(rendered.bandIsAtTop, "recovery must put a y-down capture's band at the top")
        expect(rendered.contentIsUpright, "recovery must not leave a y-down capture's content mirrored")
    }

    // MARK: - Skipping

    /// Most layers in a capture draw nothing. Keeping their empty images would
    /// multiply a document's memory for no visible gain.
    private static func testEmptyLayerProducesNoImage() {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        expect(LKXcodeViewHierarchyPixelRecovery.renderingPNG(
            of: layer, includingSublayers: true, isFlipped: false
        ) == nil, "a fully transparent layer should not produce an image")
    }

    private static func testZeroSizedLayerProducesNoImage() {
        let layer = CALayer()
        layer.bounds = .zero
        layer.backgroundColor = NSColor.red.cgColor
        expect(LKXcodeViewHierarchyPixelRecovery.renderingPNG(
            of: layer, includingSublayers: true, isFlipped: false
        ) == nil, "a zero-sized layer should not produce an image")
    }

    /// A full-screen retina layer is already megapixels and a capture holds
    /// thousands; without the cap a large window costs gigabytes to import.
    private static func testLargeLayerIsScaledWithinTheCap() {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 6000, height: 4000)
        layer.contentsScale = 2
        layer.backgroundColor = NSColor.red.cgColor
        guard let data = LKXcodeViewHierarchyPixelRecovery.renderingPNG(
            of: layer, includingSublayers: true, isFlipped: false
        ) else { fail("a large opaque layer should still render") }
        guard let image = NSBitmapImageRep(data: data) else { fail("rendered data was not a bitmap") }
        let renderedPixelCount = image.pixelsWide * image.pixelsHigh
        expect(renderedPixelCount <= LKXcodeViewHierarchyPixelRecovery.maximumRenderedPixelCount,
               "rendered \(renderedPixelCount) pixels, above the cap")
        expect(image.pixelsWide > 1000, "the cap should reduce the scale, not the usefulness")
    }

    // MARK: - Archive decoding

    /// The archive's root is a dictionary, not the layer itself; reading it as
    /// a layer yields nothing at all.
    private static func testArchiveRoundTripsThroughDecoder() {
        let root = orientationFixture()
        guard let archiveData = archiveData(rootLayer: root, geometryFlipped: true) else {
            fail("could not build the archive fixture")
        }
        guard let tree = LKXcodeViewHierarchyLayerArchive.decodingLayerTree(
            from: archiveData, rootObjectIdentifier: "0x1"
        ) else { fail("archive did not decode") }
        expect(tree.rootObjectIdentifier == "0x1", "root identifier should be carried through")
        expect(tree.isGeometryFlipped, "the geometryFlipped flag should survive the round trip")
        expect(tree.rootLayer.sublayers?.count == 1, "the sublayer should survive the round trip")
    }

    private static func testMalformedArchiveIsRejected() {
        let garbage = Data("not an archive".utf8)
        expect(LKXcodeViewHierarchyLayerArchive.decodingLayerTree(
            from: garbage, rootObjectIdentifier: "0x1"
        ) == nil, "a malformed archive must be rejected rather than trapping")
    }

    // MARK: - Fixtures

    /// A 100×100 root holding a 100×20 band pinned at the coordinate origin,
    /// whose contents image is red across its first rows and green across its
    /// last.
    ///
    /// Both asymmetries are needed. The band's *placement* reveals whether the
    /// render context was flipped; the *order of its colours* reveals whether
    /// the layers were marked geometry-flipped. A plain single-colour marker
    /// only shows the first, which is how a missing geometry flip once passed
    /// a test that was supposed to catch it.
    private static func orientationFixture() -> CALayer {
        let root = CALayer()
        root.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)

        let band = CALayer()
        band.bounds = CGRect(x: 0, y: 0, width: 100, height: 20)
        band.anchorPoint = .zero
        band.position = .zero
        band.contents = twoToneImage()
        band.contentsGravity = .resize
        root.addSublayer(band)
        return root
    }

    /// An image that is red across its first rows and green across its last.
    private static func twoToneImage() -> CGImage {
        let width = 100
        let height = 20
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { fail("could not build the two-tone fixture image") }
        // Core Graphics fills from the bottom, so the image's first rows are
        // the ones with the larger y.
        context.setFillColor(NSColor.green.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        context.setFillColor(NSColor.red.cgColor)
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
        guard let image = context.makeImage() else { fail("could not rasterise the fixture image") }
        return image
    }

    private static func archiveData(rootLayer: CALayer, geometryFlipped: Bool) -> Data? {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode(
            ["rootLayer": rootLayer, "geometryFlipped": NSNumber(value: geometryFlipped)] as NSDictionary,
            forKey: NSKeyedArchiveRootObjectKey
        )
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private struct RenderedOrientation {
        let bandIsAtTop: Bool
        let bandIsAtBottom: Bool
        /// True when the band's red half precedes its green half, reading down.
        let contentIsUpright: Bool
    }

    private static func renderedFixture(
        applyingGeometryFlip shouldApplyGeometryFlip: Bool,
        flippingContext: Bool
    ) -> RenderedOrientation? {
        let root = orientationFixture()
        if shouldApplyGeometryFlip { applyGeometryFlip(to: root) }
        guard let data = LKXcodeViewHierarchyPixelRecovery.renderingPNG(
            of: root, includingSublayers: true, isFlipped: flippingContext
        ), let bitmap = NSBitmapImageRep(data: data) else { return nil }
        return measuring(bitmap)
    }

    /// Samples the two tenths at each end of the image.
    ///
    /// `NSBitmapImageRep` addresses rows from the top, so "top" and "bottom"
    /// here mean what someone looking at the image would say.
    private static func measuring(_ bitmap: NSBitmapImageRep) -> RenderedOrientation {
        let height = bitmap.pixelsHigh
        let column = bitmap.pixelsWide / 2
        let nearTop = colorName(bitmap, x: column, y: height * 5 / 100)
        let belowTop = colorName(bitmap, x: column, y: height * 15 / 100)
        let aboveBottom = colorName(bitmap, x: column, y: height * 85 / 100)
        let nearBottom = colorName(bitmap, x: column, y: height * 95 / 100)

        let bandIsAtTop = nearTop != "clear" && belowTop != "clear"
        let bandIsAtBottom = aboveBottom != "clear" && nearBottom != "clear"
        let contentIsUpright: Bool
        if bandIsAtTop {
            contentIsUpright = nearTop == "red" && belowTop == "green"
        } else if bandIsAtBottom {
            contentIsUpright = aboveBottom == "red" && nearBottom == "green"
        } else {
            contentIsUpright = false
        }
        return RenderedOrientation(
            bandIsAtTop: bandIsAtTop,
            bandIsAtBottom: bandIsAtBottom,
            contentIsUpright: contentIsUpright
        )
    }

    private static func colorName(_ bitmap: NSBitmapImageRep, x: Int, y: Int) -> String {
        guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.5 else { return "clear" }
        if color.redComponent > 0.5, color.greenComponent < 0.5 { return "red" }
        if color.greenComponent > 0.5, color.redComponent < 0.5 { return "green" }
        return "other"
    }

    private static func applyGeometryFlip(to layer: CALayer) {
        layer.isGeometryFlipped = true
        for sublayer in layer.sublayers ?? [] { applyGeometryFlip(to: sublayer) }
    }

    // MARK: - Helpers

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
