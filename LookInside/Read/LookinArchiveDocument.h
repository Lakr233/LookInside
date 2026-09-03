//
//  LookinArchiveDocument.h
//  LookInside
//
//  Phase C of multi-document support: NSDocument that wraps a `.lookin`
//  hierarchy archive on disk. Read-only by user intent; opening through
//  NSDocumentController integrates with Recent Documents, Open Recent,
//  proxy icon dragging, and Save As / Move to / Versions.
//

#import <Cocoa/Cocoa.h>

@class LookinHierarchyFile;

@interface LookinArchiveDocument : NSDocument

@property(nonatomic, strong) LookinHierarchyFile *hierarchyFile;

/// Whether the document can rebuild `hierarchyFile` for a different
/// show-backing-layers setting. A `.lookin` archive cannot: its tree is what
/// the server sent. An imported Xcode capture can, from the decoded capture
/// it keeps after import.
- (BOOL)canRebuildHierarchyFile;

/// Rebuilds `hierarchyFile` for the setting and assigns the new file when it
/// is ready; the window observes the property and rebuilds its reader. A
/// no-op unless canRebuildHierarchyFile.
- (void)rebuildHierarchyFileShowingBackingLayers:(BOOL)showBackingLayers NS_SWIFT_NAME(rebuildHierarchyFile(showingBackingLayers:));

@end
