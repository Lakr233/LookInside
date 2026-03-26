#import <AppKit/AppKit.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [AppDelegate new];
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
