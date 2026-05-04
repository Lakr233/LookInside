#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && TARGET_OS_OSX
//
//  NSCollectionView+LookinServer.h
//  LookinServer
//
//  Created by JH on 2026/5/4.
//

#import "TargetConditionals.h"
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionView (LookinServer)

@property(nonatomic, readonly, copy) NSString *lks_backgroundColorsDescription;

@end

NS_ASSUME_NONNULL_END

#endif
