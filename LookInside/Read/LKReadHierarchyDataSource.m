//
//  LKReadHierarchyDataSource.m
//  Lookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//

#import "LKReadHierarchyDataSource.h"
#import "LookinHierarchyFile.h"
#import "LookinDisplayItem.h"
#import "LKPreferenceManager.h"
#import "LookinHierarchyInfo.h"
#import "LookinDisplayItem+LookinClient.h"

@interface LKReadHierarchyDataSource ()

@property(nonatomic, strong) LKPreferenceManager *readPreferenceManager;

@end

@implementation LKReadHierarchyDataSource

- (instancetype)initWithFile:(LookinHierarchyFile *)file preferenceManager:(LKPreferenceManager *)manager {
    if (self = [self init]) {
        self.readPreferenceManager = manager;
        
        [self reloadWithHierarchyInfo:file.hierarchyInfo keepState:NO];

        if (file.soloScreenshots.count || file.groupScreenshots.count) {
            BOOL prefersViewOID = [LKHelper appInfoLooksLikeMacTarget:file.hierarchyInfo.appInfo];
            [self.flatItems enumerateObjectsUsingBlock:^(LookinDisplayItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                __block NSData *soloData = nil;
                __block NSData *groupData = nil;
                [[obj availableObjectOidsPreferView:prefersViewOID] enumerateObjectsUsingBlock:^(NSNumber *oidNumber, NSUInteger idx, BOOL *stop) {
                    soloData = file.soloScreenshots[oidNumber];
                    groupData = file.groupScreenshots[oidNumber];
                    if (soloData || groupData) {
                        *stop = YES;
                    }
                }];
                
                if (soloData) {
                    NSImage *soloImage = [[NSImage alloc] initWithData:soloData];
                    obj.soloScreenshot = soloImage;
                }
                
                if (groupData) {
                    NSImage *groupImage = [[NSImage alloc] initWithData:groupData];
                    obj.groupScreenshot = groupImage;                    
                }
            }];
        }
    }
    return self;
}

- (LKPreferenceManager *)preferenceManager {
    return self.readPreferenceManager;
}

@end
