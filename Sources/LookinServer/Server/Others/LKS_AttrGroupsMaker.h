#if defined(SHOULD_COMPILE_LOOKIN_SERVER)
//
//  LKS_AttrGroupsMaker.h
//  LookinServer
//
//  Created by Li Kai on 2019/6/6.
//  https://lookin.work
//

#import "LookinDefines.h"

@class LookinAttributesGroup;
#if TARGET_OS_OSX
@class NSView, NSWindow;
#endif
#if TARGET_OS_IPHONE
@class UIWindowScene;
#endif

@interface LKS_AttrGroupsMaker : NSObject

#if TARGET_OS_OSX

+ (NSArray<LookinAttributesGroup *> *)attrGroupsForView:(NSView *)view;

+ (NSArray<LookinAttributesGroup *> *)attrGroupsForWindow:(NSWindow *)window;

#endif

+ (NSArray<LookinAttributesGroup *> *)attrGroupsForLayer:(CALayer *)layer;

#if TARGET_OS_IPHONE
+ (NSArray<LookinAttributesGroup *> *)attrGroupsForWindowScene:(UIWindowScene *)windowScene API_AVAILABLE(ios(13.0));
#endif

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
