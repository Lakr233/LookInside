//
//  LookinAttributesGroup+LookinClient.m
//  LookinClient
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//  Copyright © 2023 hughkli. All rights reserved.
//

#import "LookinAttributesGroup+LookinClient.h"
#import "LookinDashboardBlueprint.h"
#import "LookinAttrIdentifiers.h"
#import "LKHelper.h"

@implementation LookinAttributesGroup (LookinClient)

- (NSString *)queryDisplayTitleForMacTarget:(BOOL)isMacTarget {
    if (self.userCustomTitle.length > 0) {
        return self.userCustomTitle;
    }
    if ([self.identifier isEqualToString:LookinAttrGroup_ViewLayer]) {
        // +groupTitleWithGroupID: picks this title with TARGET_OS_IPHONE, which is
        // always 0 in the host, so it would say "NSView" even for an iOS target.
        return [NSString stringWithFormat:@"CALayer / %@", [LKHelper viewClassNameForMacTarget:isMacTarget]];
    }
    if ([self.identifier isEqualToString:LookinAttrGroup_LayoutGuide]) {
        // The group ID is platform-neutral; the title names the inspected
        // platform's actual class.
        return isMacTarget ? @"NSLayoutGuide" : @"UILayoutGuide";
    }
    return [LookinDashboardBlueprint groupTitleWithGroupID:self.identifier];
}

@end
