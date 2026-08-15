#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && TARGET_OS_IPHONE
//
//  UIWindowScene+LookinServer.m
//  LookinServer
//

#import "UIWindowScene+LookinServer.h"
#import "NSObject+LookinServer.h"
#import "NSArray+Lookin.h"
#import <objc/message.h>

@implementation UIWindowScene (LookinServer)

- (NSArray<NSArray<NSString *> *> *)lks_relatedClassChainList {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
    NSArray<NSString *> *completedList = [self lks_classChainList];
    NSUInteger endingIndex = [completedList indexOfObject:@"UIScene"];
    if (endingIndex != NSNotFound) {
        completedList = [completedList subarrayWithRange:NSMakeRange(0, endingIndex + 1)];
    }
    [array addObject:completedList];
    return array.copy;
}

- (NSArray<NSString *> *)lks_selfRelation {
    NSMutableArray *array = [NSMutableArray array];
    if (self.delegate) {
        [array addObject:[NSString stringWithFormat:@"(%@ *) delegate", NSStringFromClass([(NSObject *)self.delegate class])]];
    }
    return array.copy;
}

// -coordinateSpace and -interfaceOrientation were both deprecated in iOS 26 in
// favour of -effectiveGeometry. Prefer the new source where it exists and fall
// back to the old property below it, so a single row keeps working across
// versions. effectiveGeometry itself arrived in iOS 16, but only exposes
// coordinateSpace from iOS 26 onwards — hence the two different thresholds.
- (CGRect)lks_coordinateSpaceBounds {
#if defined(__IPHONE_26_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_26_0
    if (@available(iOS 26.0, tvOS 26.0, *)) {
        return self.effectiveGeometry.coordinateSpace.bounds;
    }
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return self.coordinateSpace.bounds;
#pragma clang diagnostic pop
}

#if !TARGET_OS_TV
- (NSInteger)lks_interfaceOrientation {
    if (@available(iOS 16.0, *)) {
        return (NSInteger)self.effectiveGeometry.interfaceOrientation;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return (NSInteger)self.interfaceOrientation;
#pragma clang diagnostic pop
}
#endif

- (NSInteger)lks_windowCount {
    return (NSInteger)self.windows.count;
}

- (NSString *)lks_keyWindowClassName {
    UIWindow *keyWindow = nil;
    if (@available(iOS 15.0, tvOS 15.0, *)) {
        keyWindow = self.keyWindow;
    } else {
        for (UIWindow *window in self.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }
    return keyWindow ? NSStringFromClass(keyWindow.class) : nil;
}

- (CGRect)lks_screenBounds {
#if TARGET_OS_VISION
    return self.coordinateSpace.bounds;
#else
    return self.screen ? self.screen.bounds : CGRectZero;
#endif
}

- (CGFloat)lks_screenScale {
#if TARGET_OS_VISION
    return 2.0;
#else
    return self.screen ? self.screen.scale : 1.0;
#endif
}

- (BOOL)lks_statusBarHidden {
#if TARGET_OS_TV
    return YES;
#else
    return self.statusBarManager ? self.statusBarManager.isStatusBarHidden : YES;
#endif
}

- (NSInteger)lks_statusBarStyle {
#if TARGET_OS_TV
    return 0;
#else
    return self.statusBarManager ? (NSInteger)self.statusBarManager.statusBarStyle : 0;
#endif
}

- (CGRect)lks_statusBarFrame {
#if TARGET_OS_TV
    return CGRectZero;
#else
    return self.statusBarManager ? self.statusBarManager.statusBarFrame : CGRectZero;
#endif
}

- (NSInteger)lks_userInterfaceStyle {
    return (NSInteger)self.traitCollection.userInterfaceStyle;
}

- (NSInteger)lks_horizontalSizeClass {
    return (NSInteger)self.traitCollection.horizontalSizeClass;
}

- (NSInteger)lks_verticalSizeClass {
    return (NSInteger)self.traitCollection.verticalSizeClass;
}

- (NSString *)lks_sessionPersistentIdentifier {
    return self.session.persistentIdentifier;
}

- (NSString *)lks_sessionRole {
    return self.session.role;
}

- (NSInteger)lks_userInterfaceLevel {
#if TARGET_OS_TV
    return 0;
#else
    return (NSInteger)self.traitCollection.userInterfaceLevel;
#endif
}

- (NSInteger)lks_activeAppearance {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        return (NSInteger)self.traitCollection.activeAppearance;
    }
    return -1;
}

- (NSInteger)lks_accessibilityContrast {
    return (NSInteger)self.traitCollection.accessibilityContrast;
}

- (NSInteger)lks_legibilityWeight {
    return (NSInteger)self.traitCollection.legibilityWeight;
}

- (CGFloat)lks_traitDisplayScale {
    return self.traitCollection.displayScale;
}

- (NSInteger)lks_displayGamut {
    return (NSInteger)self.traitCollection.displayGamut;
}

- (NSInteger)lks_userInterfaceIdiom {
    return (NSInteger)self.traitCollection.userInterfaceIdiom;
}

- (NSInteger)lks_layoutDirection {
    return (NSInteger)self.traitCollection.layoutDirection;
}

- (NSString *)lks_preferredContentSizeCategory {
    return self.traitCollection.preferredContentSizeCategory;
}

- (NSInteger)lks_sceneCaptureState {
    if (@available(iOS 17.0, tvOS 17.0, *)) {
        return (NSInteger)self.traitCollection.sceneCaptureState;
    }
    return -1;
}

- (NSInteger)lks_imageDynamicRange {
    if (@available(iOS 17.0, tvOS 17.0, *)) {
        return (NSInteger)self.traitCollection.imageDynamicRange;
    }
    return -1;
}

- (NSString *)lks_typesettingLanguage {
    if (@available(iOS 17.0, tvOS 17.0, *)) {
        return self.traitCollection.typesettingLanguage;
    }
    return nil;
}

#pragma mark - UISceneSession

- (NSString *)lks_sessionStateRestorationActivityType {
    return self.session.stateRestorationActivity.activityType;
}

- (NSString *)lks_sessionUserInfoJSONString {
    NSDictionary<NSString *, id> *userInfo = self.session.userInfo;
    if (userInfo.count == 0) {
        return nil;
    }
    // userInfo holds plist types, which is a wider set than JSON: dates and data
    // are legal there and would make serialization fail. Fall back to the plain
    // description rather than dropping the row.
    if (![NSJSONSerialization isValidJSONObject:userInfo]) {
        return userInfo.description;
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo options:NSJSONWritingPrettyPrinted error:NULL];
    if (!jsonData) {
        return userInfo.description;
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - UISceneConfiguration

- (NSString *)lks_configurationName {
    return self.session.configuration.name;
}

- (NSString *)lks_configurationSceneClassName {
    Class sceneClass = self.session.configuration.sceneClass;
    return sceneClass ? NSStringFromClass(sceneClass) : nil;
}

- (NSString *)lks_configurationDelegateClassName {
    Class delegateClass = self.session.configuration.delegateClass;
    return delegateClass ? NSStringFromClass(delegateClass) : nil;
}

- (NSString *)lks_configurationStoryboardDescription {
    UIStoryboard *storyboard = self.session.configuration.storyboard;
    if (!storyboard) {
        return nil;
    }
    // UIStoryboard exposes no public name, and its description is just the
    // pointer. Ask for the private -name and fall back when it is gone.
    SEL nameSelector = NSSelectorFromString(@"name");
    if ([storyboard respondsToSelector:nameSelector]) {
        id name = ((id (*)(id, SEL))objc_msgSend)(storyboard, nameSelector);
        if ([name isKindOfClass:[NSString class]] && ((NSString *)name).length > 0) {
            return name;
        }
    }
    return storyboard.description;
}

#pragma mark - UIWindowSceneGeometry

- (NSValue *)lks_geometrySystemFrame {
#if TARGET_OS_MACCATALYST
    if (@available(macCatalyst 16.0, *)) {
        return [NSValue valueWithCGRect:self.effectiveGeometry.systemFrame];
    }
#endif
    return nil;
}

- (NSNumber *)lks_geometryInterfaceOrientationLocked {
#if defined(__IPHONE_26_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_26_0
#if !TARGET_OS_TV && !TARGET_OS_VISION
    if (@available(iOS 26.0, *)) {
        return @(self.effectiveGeometry.isInterfaceOrientationLocked);
    }
#endif
#endif
    return nil;
}

- (NSNumber *)lks_geometryInteractivelyResizing {
#if defined(__IPHONE_26_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_26_0
    if (@available(iOS 26.0, tvOS 26.0, *)) {
        return @(self.effectiveGeometry.isInteractivelyResizing);
    }
#endif
    return nil;
}

#pragma mark - UISceneActivationConditions

- (NSString *)lks_canActivateForTargetContentIdentifierPredicateFormat {
    return self.activationConditions.canActivateForTargetContentIdentifierPredicate.predicateFormat;
}

- (NSString *)lks_prefersToActivateForTargetContentIdentifierPredicateFormat {
    return self.activationConditions.prefersToActivateForTargetContentIdentifierPredicate.predicateFormat;
}

#pragma mark - UISceneSizeRestrictions

- (NSValue *)lks_sizeRestrictionsMinimumSize {
#if !TARGET_OS_TV
    UISceneSizeRestrictions *sizeRestrictions = self.sizeRestrictions;
    if (sizeRestrictions) {
        return [NSValue valueWithCGSize:sizeRestrictions.minimumSize];
    }
#endif
    return nil;
}

- (NSValue *)lks_sizeRestrictionsMaximumSize {
#if !TARGET_OS_TV
    UISceneSizeRestrictions *sizeRestrictions = self.sizeRestrictions;
    if (sizeRestrictions) {
        return [NSValue valueWithCGSize:sizeRestrictions.maximumSize];
    }
#endif
    return nil;
}

- (NSNumber *)lks_sizeRestrictionsAllowsFullScreen {
#if TARGET_OS_MACCATALYST
    if (@available(macCatalyst 16.0, *)) {
        UISceneSizeRestrictions *sizeRestrictions = self.sizeRestrictions;
        if (sizeRestrictions) {
            return @(sizeRestrictions.allowsFullScreen);
        }
    }
#endif
    return nil;
}

#pragma mark - UISceneWindowingBehaviors

- (NSNumber *)lks_windowingBehaviorsClosable {
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        UISceneWindowingBehaviors *windowingBehaviors = self.windowingBehaviors;
        if (windowingBehaviors) {
            return @(windowingBehaviors.isClosable);
        }
    }
    return nil;
}

- (NSNumber *)lks_windowingBehaviorsMiniaturizable {
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        UISceneWindowingBehaviors *windowingBehaviors = self.windowingBehaviors;
        if (windowingBehaviors) {
            return @(windowingBehaviors.isMiniaturizable);
        }
    }
    return nil;
}

- (NSNumber *)lks_fullScreen {
#if TARGET_OS_MACCATALYST
    if (@available(macCatalyst 16.0, *)) {
        return @(self.isFullScreen);
    }
#endif
    return nil;
}

#pragma mark - Pointer lock and system protection

- (NSNumber *)lks_pointerLocked {
#if !TARGET_OS_TV
    if (@available(iOS 14.0, *)) {
        UIPointerLockState *pointerLockState = self.pointerLockState;
        if (pointerLockState) {
            return @(pointerLockState.isLocked);
        }
    }
#endif
    return nil;
}

- (NSNumber *)lks_systemProtectionUserAuthenticationEnabled {
#if !TARGET_OS_TV && !TARGET_OS_VISION
    if (@available(iOS 18.0, *)) {
        UISceneSystemProtectionManager *systemProtectionManager = self.systemProtectionManager;
        if (systemProtectionManager) {
            return @(systemProtectionManager.isUserAuthenticationEnabled);
        }
    }
#endif
    return nil;
}

@end

#endif
