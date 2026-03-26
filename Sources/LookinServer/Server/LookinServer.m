#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && (TARGET_OS_IPHONE || TARGET_OS_TV || TARGET_OS_VISION || TARGET_OS_MAC)

#import "LookinServer.h"
#import "LKS_ConnectionManager.h"

void LookinServerStart(void) {
    [LKS_ConnectionManager sharedInstance];
}

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
