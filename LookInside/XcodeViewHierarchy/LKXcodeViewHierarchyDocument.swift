// LKXcodeViewHierarchyDocument.swift
//
// The document type for Xcode-exported `.viewhierarchy` captures, and the
// import pipeline behind it.
//
// It subclasses `LookinArchiveDocument` rather than `NSDocument` directly so
// that the entire reader — window controller, hierarchy tree, preview,
// dashboard — is reused untouched. By the time this document finishes reading,
// it holds an ordinary `LookinHierarchyFile`, indistinguishable from one that
// came out of a `.lookin` archive, and everything downstream stays unaware
// that Xcode produced it.
//
// A `.viewhierarchy` is a package directory rather than a flat file, so
// reading goes through `read(from:ofType:)`; the superclass's data-based
// entry point never sees it.

import AppKit
import Foundation

enum LKXcodeViewHierarchyImporter {
    /// Reads a capture and converts it into the inspector's model.
    ///
    /// Runs synchronously and is not cheap — a large AppKit window takes a few
    /// seconds, most of it rendering the recovered layer trees. It must stay on
    /// one thread because pixel recovery mutates those trees while rendering.
    static func importingHierarchyFile(at url: URL) throws -> LookinHierarchyFile {
        let bundle = try LKXcodeViewHierarchyBundleReader.reading(contentsOf: url)
        let screenshots = LKXcodeViewHierarchyPixelRecovery.recovering(from: bundle.graph)
        return try LKXcodeViewHierarchyConverter.makingHierarchyFile(from: bundle, screenshots: screenshots)
    }
}

@objc(LKXcodeViewHierarchyDocument)
final class LKXcodeViewHierarchyDocument: LookinArchiveDocument {
    override func read(from url: URL, ofType typeName: String) throws {
        hierarchyFile = try LKXcodeViewHierarchyImporter.importingHierarchyFile(at: url)
    }

    /// Reading renders every recovered layer tree, so keep it off the
    /// concurrent path the superclass would otherwise be free to take.
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }
}
