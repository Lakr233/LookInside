#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && (TARGET_OS_IPHONE || TARGET_OS_TV || TARGET_OS_VISION || TARGET_OS_MAC)
//
//  LKS_HierarchyDetailsHandler.m
//  LookinServer
//
//  Created by Li Kai on 2019/6/20.
//  https://lookin.work
//

#import "LKS_HierarchyDetailsHandler.h"
#import "LookinDisplayItemDetail.h"
#import "LookinStaticAsyncUpdateTask.h"
#import "NSObject+LookinServer.h"
#import "CALayer+LookinServer.h"
#import "LKS_AttrGroupsMaker.h"
#import "LKS_HierarchyDisplayItemsMaker.h"

@interface LKS_HierarchyDetailsHandler ()

@property(nonatomic, assign) BOOL cancelled;

@end

@implementation LKS_HierarchyDetailsHandler

- (void)startWithPackages:(NSArray<LookinStaticAsyncUpdateTasksPackage *> *)packages block:(LKS_HierarchyDetailsHandler_ProgressBlock)progressBlock finishedBlock:(LKS_HierarchyDetailsHandler_FinishBlock)finishBlock {
    if (!progressBlock || !finishBlock) {
        return;
    }
    if (!packages.count) {
        finishBlock();
        return;
    }

    for (LookinStaticAsyncUpdateTasksPackage *package in packages) {
        if (self.cancelled) {
            return;
        }
        NSMutableArray<LookinDisplayItemDetail *> *details = [NSMutableArray array];
        for (LookinStaticAsyncUpdateTask *task in package.tasks ?: @[]) {
            LookinDisplayItemDetail *detail = [LookinDisplayItemDetail new];
            detail.displayItemOid = task.oid;
            CALayer *layer = (CALayer *)[NSObject lks_objectWithOid:task.oid];
            if (![layer isKindOfClass:[CALayer class]]) {
                detail.failureCode = -1;
                [details addObject:detail];
                continue;
            }
            if (task.taskType == LookinStaticAsyncUpdateTaskTypeSoloScreenshot) {
                detail.soloScreenshot = [layer lks_soloScreenshotWithLowQuality:NO];
            } else if (task.taskType == LookinStaticAsyncUpdateTaskTypeGroupScreenshot) {
                detail.groupScreenshot = [layer lks_groupScreenshotWithLowQuality:NO];
            }
            if (task.needBasisVisualInfo) {
                detail.frameValue = [NSValue valueWithRect:layer.frame];
                detail.boundsValue = [NSValue valueWithRect:layer.bounds];
                detail.hiddenValue = @(layer.hidden);
                detail.alphaValue = @(layer.opacity);
            }
            if (task.needSubitems) {
                detail.subitems = [LKS_HierarchyDisplayItemsMaker subitemsOfLayer:layer];
            }
            if (task.attrRequest != LookinDetailUpdateTaskAttrRequest_NotNeed) {
                detail.attributesGroupList = [LKS_AttrGroupsMaker attrGroupsForLayer:layer];
            }
            [details addObject:detail];
        }
        progressBlock(details.copy);
    }
    if (!self.cancelled) {
        finishBlock();
    }
}

- (void)cancel {
    self.cancelled = YES;
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
