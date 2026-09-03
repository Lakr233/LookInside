//
//  LKReadWindowController.m
//  Lookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//

#import "LKReadWindowController.h"
#import "LKReadViewController.h"
#import "LKWindowToolbarHelper.h"
#import "LookinHierarchyFile.h"
#import "LKPreferenceManager.h"
#import "LKReadHierarchyDataSource.h"
#import "LookinHierarchyInfo.h"
#import "LKWindow.h"
#import "LKMenuPopoverSettingController.h"
#import "LKPreviewView.h"
#import "LKHierarchyView.h"
#import "LookinArchiveDocument.h"
#import "LKHelper.h"
#import "LKBaseView.h"
#import "LKLabel.h"

/// What the window shows while a document is still importing in the
/// background: an indeterminate spinner and one line of text.
@interface LKReadLoadingView : LKBaseView
@end

@implementation LKReadLoadingView {
    NSProgressIndicator *_indicator;
    LKLabel *_titleLabel;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        _indicator = [NSProgressIndicator new];
        _indicator.indeterminate = YES;
        _indicator.style = NSProgressIndicatorStyleSpinning;
        _indicator.controlSize = NSControlSizeRegular;
        [self addSubview:_indicator];
        [_indicator startAnimation:nil];

        _titleLabel = [LKLabel new];
        _titleLabel.textColor = [NSColor secondaryLabelColor];
        _titleLabel.font = NSFontMake(14);
        _titleLabel.stringValue = NSLocalizedString(@"Loading capture…", nil);
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)layout {
    [super layout];
    [_indicator sizeToFit];
    $(_titleLabel).sizeToFit.x(_indicator.$maxX + 8).midY(_indicator.$midY);
    $(_indicator, _titleLabel).groupHorAlign.midY(self.$height * .5);
}

@end

@interface LKReadWindowController () <NSToolbarDelegate>

@property(nonatomic, strong) LKReadViewController *viewController;

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSToolbarItem *> *toolbarItemsMap;

@property(nonatomic, strong, readwrite) LKPreferenceManager *preferenceManager;

@end

@implementation LKReadWindowController

- (instancetype)initWithDocument:(LookinArchiveDocument *)document {
    NSSize screenSize = [NSScreen mainScreen].frame.size;
    LKWindow *window = [[LKWindow alloc] initWithContentRect:NSMakeRect(0, 0, screenSize.width * .7, screenSize.height * .7) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable|NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:YES];
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    if (@available(macOS 11.0, *)) {
        window.toolbarStyle = NSWindowToolbarStyleUnified;
    }
    window.minSize = NSMakeSize(800, 500);
    [window center];
    
    if (self = [self initWithWindow:window]) {
        self.preferenceManager = [LKPreferenceManager new];
        if (!document.hierarchyFile) {
            // The document is still importing in the background (an Xcode
            // capture): hold the window on a placeholder until the file lands.
            window.contentView = [LKReadLoadingView new];
        }
        // Every file the document produces gets a reader built in place: the
        // one that lands after the import, and each rebuild the backing-layer
        // toggle asks for.
        @weakify(self);
        [[[RACObserve(document, hierarchyFile) ignore:nil] distinctUntilChanged] subscribeNext:^(LookinHierarchyFile *file) {
            @strongify(self);
            [self _showHierarchyFile:file];
        }];
        // Flipping the toggle changes the node set itself, so — as in a live
        // session — the tree is rebuilt whole, by the document, when it can.
        [self.preferenceManager.showBackingLayers subscribe:self
                                                     action:@selector(_handleShowBackingLayersDidChange:)
                                              relatedObject:nil];
    }
    return self;
}

- (void)_handleShowBackingLayersDidChange:(LookinMsgActionParams *)param {
    LookinArchiveDocument *document = self.document;
    if (![document canRebuildHierarchyFile]) {
        return;
    }
    // Back to the placeholder; the new file's reader replaces it. Toolbar
    // items belong to one toolbar, so they are made afresh for the new one.
    self.contentViewController = nil;
    _viewController = nil;
    self.toolbarItemsMap = nil;
    self.window.toolbar = nil;
    self.window.contentView = [LKReadLoadingView new];
    [document rebuildHierarchyFileShowingBackingLayers:param.boolValue];
}

/// Builds the reader for `file` in this window: the view controller, the
/// measure button's enabled state, and the toolbar, whose items need the
/// data source to exist.
- (void)_showHierarchyFile:(LookinHierarchyFile *)file {
    NSWindow *window = self.window;
    _viewController = [[LKReadViewController alloc] initWithFile:file preferenceManager:self.preferenceManager];
    // Setting contentViewController sizes the window to the view; keep the
    // size the window already has.
    self.viewController.view.frame = window.contentView.bounds;
    window.contentView = self.viewController.view;
    self.contentViewController = self.viewController;
    
    @weakify(self);
    [RACObserve(self.viewController.hierarchyDataSource, selectedItem) subscribeNext:^(id  _Nullable x) {
        @strongify(self);
        NSButton *measureButton = (NSButton *)self.toolbarItemsMap[LKToolBarIdentifier_Measure].view;
        BOOL canMeasure = !!x;
        measureButton.enabled = canMeasure;
    }];
    
    NSToolbar *toolbar = [[NSToolbar alloc] init];
    toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
    toolbar.sizeMode = NSToolbarSizeModeRegular;
    toolbar.delegate = self;
    window.toolbar = toolbar;
}

#pragma mark - NSToolbarDelegate

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[LKToolBarIdentifier_AppInReadMode, NSToolbarFlexibleSpaceItemIdentifier, LKToolBarIdentifier_Dimension, LKToolBarIdentifier_Rotation, LKToolBarIdentifier_Setting, NSToolbarFlexibleSpaceItemIdentifier, LKToolBarIdentifier_Scale, NSToolbarFlexibleSpaceItemIdentifier, LKToolBarIdentifier_Measure];
}

- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = self.toolbarItemsMap[itemIdentifier];
    if (!item) {
        if (!self.toolbarItemsMap) {
            self.toolbarItemsMap = [NSMutableDictionary dictionary];
        }
        if ([itemIdentifier isEqualToString:LKToolBarIdentifier_AppInReadMode]) {
            item = [[LKWindowToolbarHelper sharedInstance] makeAppInReadModeItemWithAppInfo:self.viewController.hierarchyDataSource.rawHierarchyInfo.appInfo];
        } else {
            item = [[LKWindowToolbarHelper sharedInstance] makeToolBarItemWithIdentifier:itemIdentifier preferenceManager:self.preferenceManager];
        }
        self.toolbarItemsMap[itemIdentifier] = item;
        
        if ([item.itemIdentifier isEqualToString:LKToolBarIdentifier_Setting]) {
            item.label = NSLocalizedString(@"View", nil);
            item.target = self;
            item.action = @selector(_handleSetting:);
        } else if ([item.itemIdentifier isEqualToString:LKToolBarIdentifier_Rotation]) {
            item.target = self;
            item.action = @selector(_handleFreeRotation);
        }
    }
    return item;
}
#pragma mark - Event Handler

- (void)_handleSetting:(NSButton *)button {
    NSPopover *popover = [[NSPopover alloc] init];
    popover.behavior = NSPopoverBehaviorTransient;
    popover.animates = NO;
    popover.contentSize = NSMakeSize(IsEnglish ? 270 : 350, 260);
    LookinAppInfo *inspectedAppInfo = self.viewController.hierarchyDataSource.rawHierarchyInfo.appInfo;
    popover.contentViewController = [[LKMenuPopoverSettingController alloc] initWithPreferenceManager:self.preferenceManager
                                                                                          isMacTarget:[LKHelper appInfoLooksLikeMacTarget:inspectedAppInfo]];
    [popover showRelativeToRect:NSMakeRect(0, 0, button.bounds.size.width, button.bounds.size.height) ofView:button preferredEdge:NSRectEdgeMaxY];
}

- (void)_handleFreeRotation {
    LKPreferenceManager *manager = self.preferenceManager;
    BOOL boolValue = manager.freeRotation.currentBOOLValue;
    [manager.freeRotation setBOOLValue:!boolValue ignoreSubscriber:nil];
}

#pragma mark - <LKAppMenuManagerDelegate>

- (void)appMenuManagerDidSelectDimension {
    if (self.preferenceManager.previewDimension.currentIntegerValue == LookinPreviewDimension2D) {
        [self.preferenceManager.previewDimension setIntegerValue:LookinPreviewDimension3D ignoreSubscriber:nil];
    } else {
        [self.preferenceManager.previewDimension setIntegerValue:LookinPreviewDimension2D ignoreSubscriber:nil];
    }
}

- (void)appMenuManagerDidSelectZoomIn {
    LKPreferenceManager *manager = self.preferenceManager;
    double currentScale = manager.previewScale.currentDoubleValue;
    double targetScale = MIN(MAX(currentScale + 0.1, LookinPreviewMinScale), LookinPreviewMaxScale);
    [manager.previewScale setDoubleValue:targetScale ignoreSubscriber:nil];
}

- (void)appMenuManagerDidSelectZoomOut {
    LKPreferenceManager *manager = self.preferenceManager;
    double currentScale = manager.previewScale.currentDoubleValue;
    double targetScale = MIN(MAX(currentScale - 0.1, LookinPreviewMinScale), LookinPreviewMaxScale);
    [manager.previewScale setDoubleValue:targetScale ignoreSubscriber:nil];
}

- (void)appMenuManagerDidSelectDecreaseInterspace {
    LKPreferenceManager *manager = self.preferenceManager;
    double currentValue = manager.zInterspace.currentDoubleValue;
    double newValue = currentValue - 0.1;
    newValue = MIN(MAX(newValue, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace);
    [manager.zInterspace setDoubleValue:newValue ignoreSubscriber:nil];
}

- (void)appMenuManagerDidSelectIncreaseInterspace {
    LKPreferenceManager *manager = self.preferenceManager;
    double currentValue = manager.zInterspace.currentDoubleValue;
    double newValue = currentValue + 0.1;
    newValue = MIN(MAX(newValue, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace);
    [manager.zInterspace setDoubleValue:newValue ignoreSubscriber:nil];
}

- (void)appMenuManagerDidSelectExpansionIndex:(NSUInteger)index {
    [self.viewController.hierarchyDataSource adjustExpansionByIndex:index referenceDict:nil selectedItem:nil];
}

- (void)appMenuManagerDidSelectFilter {
    [[self.viewController currentHierarchyView] activateSearchBar];
}

@end
