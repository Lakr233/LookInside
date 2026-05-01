#import "LKSwiftUIHierarchyDisplayMode.h"

NSNotificationName const LKSwiftUIHierarchyDisplayModeDidChangeNotification =
    @"LKSwiftUIHierarchyDisplayModeDidChangeNotification";

static NSString *const kDefaultsKey = @"LookInside.SwiftUIHierarchyDisplayMode";

@implementation LKSwiftUIHierarchyDisplayModeStore

+ (LKSwiftUIHierarchyDisplayMode)currentMode {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:kDefaultsKey] == nil) {
        return LKSwiftUIHierarchyDisplayModeCompact;
    }
    NSInteger raw = [defaults integerForKey:kDefaultsKey];
    if (raw == LKSwiftUIHierarchyDisplayModeVerbose
        || raw == LKSwiftUIHierarchyDisplayModeCompact) {
        return (LKSwiftUIHierarchyDisplayMode)raw;
    }
    return LKSwiftUIHierarchyDisplayModeCompact;
}

+ (void)setCurrentMode:(LKSwiftUIHierarchyDisplayMode)mode {
    LKSwiftUIHierarchyDisplayMode old = [self currentMode];
    if (old == mode) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setInteger:mode forKey:kDefaultsKey];
    [NSNotificationCenter.defaultCenter postNotificationName:LKSwiftUIHierarchyDisplayModeDidChangeNotification
                                                      object:self.class];
}

+ (void)swiftUIModeSegmentChanged:(NSSegmentedControl *)sender {
    LKSwiftUIHierarchyDisplayMode mode = (sender.selectedSegment == 0)
        ? LKSwiftUIHierarchyDisplayModeCompact
        : LKSwiftUIHierarchyDisplayModeVerbose;
    [self setCurrentMode:mode];
}

@end
