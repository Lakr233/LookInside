//
//  LKMenuPopoverSettingController.h
//  Lookin
//
//  Created by Li Kai on 2019/1/9.
//  https://lookin.work
//

#import "LKBaseViewController.h"

@class LKPreferenceManager;

@interface LKMenuPopoverSettingController : LKBaseViewController

/// `isMacTarget` describes the app being inspected, not the host. It decides whether the
/// copy talks about `NSView` or `UIView`.
- (instancetype)initWithPreferenceManager:(LKPreferenceManager *)manager isMacTarget:(BOOL)isMacTarget;

@end
