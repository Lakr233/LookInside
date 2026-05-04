#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && TARGET_OS_OSX
//
//  NSDatePicker+LookinServer.h
//  LookinServer
//
//  Created by JH on 2026/5/4.
//

#import "TargetConditionals.h"
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDatePicker (LookinServer)

@property(nonatomic, readonly, copy) NSString *lks_dateValueDescription;
@property(nonatomic, readonly, copy) NSString *lks_minDateDescription;
@property(nonatomic, readonly, copy) NSString *lks_maxDateDescription;

@end

NS_ASSUME_NONNULL_END

#endif
