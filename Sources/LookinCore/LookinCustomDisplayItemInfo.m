#ifdef SHOULD_COMPILE_LOOKIN_SERVER

//
//  LookinCustomDisplayItemInfo.m
//  LookinServer
//
//  Created by likai.123 on 2023/11/1.
//

#import "LookinCustomDisplayItemInfo.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@implementation LookinCustomDisplayItemInfo

- (id)copyWithZone:(NSZone *)zone {
    LookinCustomDisplayItemInfo *newInstance = [[LookinCustomDisplayItemInfo allocWithZone:zone] init];
    
    if (self.frameInWindow) {
#if TARGET_OS_IPHONE
        CGRect rect = [self.frameInWindow CGRectValue];
        newInstance.frameInWindow = [NSValue valueWithCGRect:rect];
#elif TARGET_OS_OSX
        CGRect rect = [self.frameInWindow rectValue];
        newInstance.frameInWindow = [NSValue valueWithRect:rect];
#endif
    }
    newInstance.title = self.title;
    newInstance.subtitle = self.subtitle;
    newInstance.danceuiSource = self.danceuiSource;
    newInstance.isSwiftUI = self.isSwiftUI;
    newInstance.swiftUIDisplayItemID = self.swiftUIDisplayItemID;

    return newInstance;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.frameInWindow forKey:@"frameInWindow"];
    [aCoder encodeObject:self.title forKey:@"title"];
    [aCoder encodeObject:self.subtitle forKey:@"subtitle"];
    [aCoder encodeObject:self.danceuiSource forKey:@"danceuiSource"];
    [aCoder encodeBool:self.isSwiftUI forKey:@"isSwiftUI"];
    [aCoder encodeObject:self.swiftUIDisplayItemID forKey:@"swiftUIDisplayItemID"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.frameInWindow = [aDecoder decodeObjectOfClass:NSValue.class forKey:@"frameInWindow"];
        self.title = [aDecoder decodeObjectOfClass:NSString.class forKey:@"title"];
        self.subtitle = [aDecoder decodeObjectOfClass:NSString.class forKey:@"subtitle"];
        self.danceuiSource = [aDecoder decodeObjectOfClass:NSString.class forKey:@"danceuiSource"];
        self.isSwiftUI = [aDecoder decodeBoolForKey:@"isSwiftUI"];
        self.swiftUIDisplayItemID = [aDecoder decodeObjectOfClass:NSString.class forKey:@"swiftUIDisplayItemID"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
