#ifdef SHOULD_COMPILE_LOOKIN_SERVER
//
//  LKS_MultiplatformAdapter.h
//
//
//  Created by nixjiang on 2024/3/12.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LKS_MultiplatformAdapter : NSObject

+ (LookinWindow *)keyWindow;

+ (NSArray<LookinWindow *> *)allWindows;

#if TARGET_OS_IPHONE
/// Returns every live UIWindowScene, including internal ones that
/// UIApplication.connectedScenes hides (e.g. _UIKeyboardWindowScene on
/// iOS 17+). Falls back to connectedScenes if the private entry point is
/// unavailable.
+ (NSArray<UIWindowScene *> *)allWindowScenes;

/// Returns every UIWindow attached to the given scene, including ones whose
/// -isInternalWindow returns YES (e.g. UIRemoteKeyboardWindow on iOS 26+,
/// which is filtered out by the public -[UIWindowScene windows] getter).
/// Falls back to scene.windows if the private getter is unavailable.
+ (NSArray<UIWindow *> *)allWindowsForWindowScene:(UIWindowScene *)scene;
#endif

+ (CGRect)mainScreenBounds;

+ (CGFloat)mainScreenScale;

/// Whether the host device is an iPad — or anything UIKit presents as one. A Mac Catalyst
/// build also answers YES: -[UIDevice model] is "iPad" there. Callers that need to tell a
/// real iPad from a Mac must consult +isMacCatalyst first.
+ (BOOL)isiPad;

/// Whether the app is a native AppKit Mac app. A Mac Catalyst build answers NO: it runs on
/// macOS but is built against UIKit, so TARGET_OS_OSX is 0 for it.
+ (BOOL)isMac;

/// Whether the app is a Mac Catalyst build — UIKit source, running on macOS.
///
/// This is a compile-time verdict rather than a runtime probe, and that is what makes it
/// exact: TARGET_OS_MACCATALYST is set for precisely the Catalyst destination, so the answer
/// is fixed the moment LookinServer is compiled into the target app.
///
/// UIKit offers nothing comparable. Measured in a Catalyst process on macOS 26.6:
/// -[UIDevice model] and -name are both "iPad", -systemName is "iPadOS", and
/// -userInterfaceIdiom is .pad — every one of them describes an iPad. (-userInterfaceIdiom
/// does become .mac under the "Optimized for Mac" interface setting, which is exactly why it
/// cannot be trusted: the answer would then depend on a per-app UI choice rather than on
/// what the app actually is.) -[NSProcessInfo isMacCatalystApp] is accurate but redundant,
/// and would move a decision that is already settled at compile time into runtime.
+ (BOOL)isMacCatalyst;

@end

NS_ASSUME_NONNULL_END

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
