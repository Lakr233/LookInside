#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LKSwiftUIHierarchyDisplayMode) {
    LKSwiftUIHierarchyDisplayModeVerbose = 0,
    LKSwiftUIHierarchyDisplayModeCompact = 1,
};

/// Posted on the main thread whenever
/// `+[LKSwiftUIHierarchyDisplayModeStore currentMode]` changes.
/// Notification object: the store class.
FOUNDATION_EXPORT NSNotificationName const LKSwiftUIHierarchyDisplayModeDidChangeNotification;

@interface LKSwiftUIHierarchyDisplayModeStore : NSObject

/// Default = compact when no value persisted yet.
+ (LKSwiftUIHierarchyDisplayMode)currentMode;

/// Persist the new mode to NSUserDefaults and post
/// LKSwiftUIHierarchyDisplayModeDidChangeNotification on the main queue if
/// the value actually changed.
+ (void)setCurrentMode:(LKSwiftUIHierarchyDisplayMode)mode;

/// IBAction-shape selector intended for an NSSegmentedControl whose
/// segment 0 is Compact and segment 1 is Verbose. Writes the new mode
/// through `+setCurrentMode:`, which posts the change notification.
+ (void)swiftUIModeSegmentChanged:(NSSegmentedControl *)sender;

@end

NS_ASSUME_NONNULL_END
