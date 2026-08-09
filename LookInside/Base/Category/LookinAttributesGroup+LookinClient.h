//
//  LookinAttributesGroup+LookinClient.h
//  LookinClient
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//  Copyright © 2023 hughkli. All rights reserved.
//

#import "LookinAttributesGroup.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinAttributesGroup (LookinClient)

/// `isMacTarget` describes the app being inspected, not the host. It only affects the
/// ViewLayer group, whose title names the view class (`NSView` vs `UIView`).
- (NSString *)queryDisplayTitleForMacTarget:(BOOL)isMacTarget;

@end

NS_ASSUME_NONNULL_END
