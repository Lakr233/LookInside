#import "AppDelegate.h"
extern void LookinServerStart(void);

@interface AppDelegate ()

@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, copy) NSArray<NSString *> *rows;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    LookinServerStart();
    self.rows = @[@"Alpha", @"Bravo", @"Charlie", @"Delta", @"Echo"];

    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(240, 240, 920, 620)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"LookInside Objective-C Host";
    window.releasedWhenClosed = NO;
    window.contentView = [self buildContentView];
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    self.window = window;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.rows.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSUserInterfaceItemIdentifier identifier = @"ObjCPlanetCell";
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 24)];
        cell.identifier = identifier;
        NSTextField *label = [NSTextField labelWithString:@""];
        label.frame = NSMakeRect(10, 2, tableColumn.width - 20, 20);
        label.wantsLayer = YES;
        [cell addSubview:label];
        cell.textField = label;
        cell.wantsLayer = YES;
    }
    cell.textField.stringValue = self.rows[(NSUInteger)row];
    return cell;
}

- (NSView *)buildContentView {
    NSVisualEffectView *root = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 920, 620)];
    root.material = NSVisualEffectMaterialMenu;
    root.state = NSVisualEffectStateActive;
    root.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    root.wantsLayer = YES;

    NSView *card = [[NSView alloc] initWithFrame:NSMakeRect(28, 28, 864, 564)];
    card.wantsLayer = YES;
    card.layer.cornerRadius = 18;
    card.layer.backgroundColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.93].CGColor;
    [root addSubview:card];

    NSTextField *title = [NSTextField labelWithString:@"Objective-C validation host"];
    title.font = [NSFont systemFontOfSize:28 weight:NSFontWeightSemibold];
    title.frame = NSMakeRect(24, 510, 380, 34);
    title.wantsLayer = YES;
    [card addSubview:title];

    NSTextField *subtitle = [NSTextField labelWithString:@"Embedded LookinServer AppKit sample"];
    subtitle.textColor = NSColor.secondaryLabelColor;
    subtitle.frame = NSMakeRect(24, 484, 360, 20);
    subtitle.wantsLayer = YES;
    [card addSubview:subtitle];

    NSButton *button = [NSButton buttonWithTitle:@"Primary Button" target:nil action:nil];
    button.frame = NSMakeRect(24, 436, 150, 32);
    button.bezelStyle = NSBezelStyleRounded;
    button.wantsLayer = YES;
    [card addSubview:button];

    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(190, 438, 220, 24)];
    field.stringValue = @"Editable NSTextField";
    field.wantsLayer = YES;
    [card addSubview:field];

    NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(24, 272, 180, 136)];
    imageView.imageScaling = NSImageScaleAxesIndependently;
    imageView.image = [NSImage imageWithSystemSymbolName:@"shippingbox.fill" accessibilityDescription:nil];
    imageView.wantsLayer = YES;
    imageView.layer.cornerRadius = 12;
    imageView.layer.backgroundColor = [[NSColor systemOrangeColor] colorWithAlphaComponent:0.18].CGColor;
    [card addSubview:imageView];

    NSVisualEffectView *effect = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(228, 274, 250, 78)];
    effect.material = NSVisualEffectMaterialPopover;
    effect.state = NSVisualEffectStateActive;
    effect.wantsLayer = YES;
    effect.layer.cornerRadius = 12;
    [card addSubview:effect];

    NSTextField *effectLabel = [NSTextField labelWithString:@"NSVisualEffectView"];
    effectLabel.frame = NSMakeRect(16, 30, 180, 20);
    effectLabel.wantsLayer = YES;
    [effect addSubview:effectLabel];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(520, 176, 300, 252)];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.wantsLayer = YES;

    NSTableView *tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"objc-col"];
    column.width = 280;
    column.title = @"Callsigns";
    [tableView addTableColumn:column];
    tableView.headerView = nil;
    tableView.rowHeight = 24;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.wantsLayer = YES;
    scrollView.documentView = tableView;
    [card addSubview:scrollView];

    return root;
}

@end
