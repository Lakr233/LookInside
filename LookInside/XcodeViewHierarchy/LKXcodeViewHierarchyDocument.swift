// LKXcodeViewHierarchyDocument.swift
//
// The document type for Xcode-exported `.viewhierarchy` captures, and the
// import pipeline behind it.
//
// It subclasses `LookinArchiveDocument` rather than `NSDocument` directly so
// that the entire reader — window controller, hierarchy tree, preview,
// dashboard — is reused untouched. Once the import lands, the document holds
// an ordinary `LookinHierarchyFile`, indistinguishable from one that came out
// of a `.lookin` archive, and everything downstream stays unaware that Xcode
// produced it.
//
// Reading is split in two. `read(from:ofType:)` only checks that the URL is a
// capture and starts the import in the background, so the window opens at
// once on a placeholder; a large AppKit window takes tens of seconds to
// import, most of it rendering the recovered layer trees, and none of that
// belongs on the main thread. The window controller observes `hierarchyFile`
// and builds the reader in place when the import finishes.

import AppKit
import Foundation

enum LKXcodeViewHierarchyImporter {
    /// Reads a capture and converts it into the inspector's model.
    ///
    /// Synchronous and not cheap; run it off the main thread. It must stay on
    /// one thread because pixel recovery mutates the decoded layer trees while
    /// rendering. `isCancelled` is polled between phases and once per rendered
    /// layer; once it answers true the import throws `CancellationError`.
    static func importingHierarchyFile(
        at url: URL,
        isCancelled: () -> Bool = { false }
    ) throws -> LookinHierarchyFile {
        let bundle = try LKXcodeViewHierarchyBundleReader.reading(contentsOf: url)
        if isCancelled() { throw CancellationError() }
        let screenshots = LKXcodeViewHierarchyPixelRecovery.recovering(from: bundle.graph, isCancelled: isCancelled)
        if isCancelled() { throw CancellationError() }
        return try LKXcodeViewHierarchyConverter.makingHierarchyFile(from: bundle, screenshots: screenshots)
    }
}

@objc(LKXcodeViewHierarchyDocument)
final class LKXcodeViewHierarchyDocument: LookinArchiveDocument {
    private var importTask: Task<Void, Never>?

    /// Validates the package and starts the import, returning before the
    /// import finishes so the window can open on its placeholder.
    override func read(from url: URL, ofType typeName: String) throws {
        try LKXcodeViewHierarchyBundleReader.validatingBundle(at: url)
        importTask?.cancel()
        importTask = Task.detached(priority: .userInitiated) { [weak self] in
            let outcome: Result<LookinHierarchyFile, Error>
            do {
                outcome = .success(try LKXcodeViewHierarchyImporter.importingHierarchyFile(at: url) { Task.isCancelled })
            } catch {
                outcome = .failure(error)
            }
            // A closed document has nothing to show and no window to complain on.
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.finishingImport(with: outcome) }
        }
    }

    override func close() {
        importTask?.cancel()
        importTask = nil
        super.close()
    }

    /// The task has to be created where `close()` can cancel it, on the
    /// main thread; the superclass's concurrent path would call `read` elsewhere.
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }

    @MainActor
    private func finishingImport(with outcome: Result<LookinHierarchyFile, Error>) {
        importTask = nil
        switch outcome {
        case .success(let file):
            // The window controller observes this and builds the reader in place.
            hierarchyFile = file
        case .failure(let error):
            let alert = NSAlert(error: error)
            if let window = windowForSheet {
                alert.beginSheetModal(for: window) { [weak self] _ in self?.close() }
            } else {
                close()
            }
        }
    }
}
