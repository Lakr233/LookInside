//
//  LKPreferenceWindowController.m
//  Lookin
//
//  Created by Li Kai on 2019/1/4.
//  https://lookin.work
//

#import "LKPreferenceWindowController.h"
#import "LKPreferenceViewController.h"
#import "LKWindow.h"

@implementation LKPreferenceWindowController

- (instancetype)init {
    CGFloat windowHeight = 410;
#if DEBUG
    windowHeight = 475;
#endif
    LKWindow *window = [[LKWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, windowHeight) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:YES];
    window.movableByWindowBackground = YES;
    window.title = NSLocalizedString(@"Preferences", nil);
    [window center];
    
    if (self = [self initWithWindow:window]) {
        LKPreferenceViewController *vc = [LKPreferenceViewController new];
        window.contentView = vc.view;
        self.contentViewController = vc;
    }
    return self;
}

@end
