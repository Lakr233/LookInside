//
//  LKReadWindowController.h
//  Lookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//

#import "LKWindowController.h"

@class LookinHierarchyFile, LKPreferenceManager, LookinArchiveDocument;

@interface LKReadWindowController : LKWindowController

/// Reader windows are owned by `LookinArchiveDocument` exclusively
/// (Phase F removed the legacy `-initWithFile:` direct entry point —
/// `LKNavigationManager.showReaderWithHierarchyFile:title:` now wraps
/// in-memory hierarchies in an untitled Archive Doc, and disk-backed
/// archives flow through `NSDocumentController.openDocumentWithContentsOfURL:`).
- (instancetype)initWithDocument:(LookinArchiveDocument *)document;

/// This window's own preference set: the reader's view settings, including
/// the show-backing-layers toggle, are per document window. A document that
/// can rebuild its tree reads the toggle from here.
@property(nonatomic, strong, readonly) LKPreferenceManager *preferenceManager;

@end
