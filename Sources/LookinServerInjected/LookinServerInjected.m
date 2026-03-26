#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <dispatch/dispatch.h>

#if TARGET_OS_MAC && !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

extern void LookinServerStart(void);

static void LKStartLookinServerIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LookinServerStart();
    });
}

static void LKRegisterLaunchObserverIfNeeded(void) {
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        LKStartLookinServerIfNeeded();
    }];
#else
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        LKStartLookinServerIfNeeded();
    }];
#endif

    // If the launch notification has already fired before injection, retry once on the main runloop.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LKStartLookinServerIfNeeded();
    });
}

__attribute__((constructor))
static void LKInjectedBootstrap(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        LKRegisterLaunchObserverIfNeeded();
    });
}
