#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && TARGET_OS_OSX
//
//  NSDatePicker+LookinServer.m
//  LookinServer
//
//  Created by JH on 2026/5/4.
//

#import "NSDatePicker+LookinServer.h"

static NSString *LKSStringFromDate(NSDate *date) {
    return date.description;
}

@implementation NSDatePicker (LookinServer)

- (NSString *)lks_dateValueDescription {
    return LKSStringFromDate(self.dateValue);
}

- (NSString *)lks_minDateDescription {
    return LKSStringFromDate(self.minDate);
}

- (NSString *)lks_maxDateDescription {
    return LKSStringFromDate(self.maxDate);
}

@end

#endif
