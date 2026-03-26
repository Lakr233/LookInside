#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && (TARGET_OS_IPHONE || TARGET_OS_TV || TARGET_OS_VISION || TARGET_OS_MAC)
//
//  LookinServer.h
//  LookinServer
//
//  Created by Li Kai on 2019/7/20.
//  https://lookin.work
//

#ifndef LookinServer_h
#define LookinServer_h

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT void LookinServerStart(void);

#endif /* LookinServer_h */

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
