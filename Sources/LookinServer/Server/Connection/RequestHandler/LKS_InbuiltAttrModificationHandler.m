#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && (TARGET_OS_IPHONE || TARGET_OS_TV || TARGET_OS_VISION || TARGET_OS_MAC)
//
//  LKS_InbuiltAttrModificationHandler.m
//  LookinServer
//
//  Created by Li Kai on 2019/6/12.
//  https://lookin.work
//

#import "LKS_InbuiltAttrModificationHandler.h"
#import "LookinAttributeModification.h"
#import "LookinDisplayItemDetail.h"
#import "LookinStaticAsyncUpdateTask.h"
#import "LKS_AttrGroupsMaker.h"
#import "NSObject+LookinServer.h"
#import "CALayer+LookinServer.h"
#import "LookinServerDefines.h"

#if TARGET_OS_MAC
#import "Color+Lookin.h"

@implementation LKS_InbuiltAttrModificationHandler

+ (void)handleModification:(LookinAttributeModification *)modification completion:(void (^)(LookinDisplayItemDetail *data, NSError *error))completion {
    if (!completion || ![modification isKindOfClass:[LookinAttributeModification class]]) {
        if (completion) {
            completion(nil, LookinErr_Inner);
        }
        return;
    }

    CALayer *receiver = (CALayer *)[NSObject lks_objectWithOid:modification.targetOid];
    if (![receiver isKindOfClass:[CALayer class]]) {
        completion(nil, LookinErr_ObjNotFound);
        return;
    }
    if (![receiver respondsToSelector:modification.setterSelector]) {
        completion(nil, LookinErr_Inner);
        return;
    }

    NSMethodSignature *setterSignature = [receiver methodSignatureForSelector:modification.setterSelector];
    if (!setterSignature || setterSignature.numberOfArguments != 3) {
        completion(nil, LookinErr_Inner);
        return;
    }

    NSInvocation *setterInvocation = [NSInvocation invocationWithMethodSignature:setterSignature];
    setterInvocation.target = receiver;
    setterInvocation.selector = modification.setterSelector;

    switch (modification.attrType) {
        case LookinAttrTypeBOOL: {
            BOOL value = [(NSNumber *)modification.value boolValue];
            [setterInvocation setArgument:&value atIndex:2];
            break;
        }
        case LookinAttrTypeFloat: {
            float value = [(NSNumber *)modification.value floatValue];
            [setterInvocation setArgument:&value atIndex:2];
            break;
        }
        case LookinAttrTypeDouble: {
            double value = [(NSNumber *)modification.value doubleValue];
            [setterInvocation setArgument:&value atIndex:2];
            break;
        }
        case LookinAttrTypeCGPoint: {
            CGPoint value = [(NSValue *)modification.value pointValue];
            [setterInvocation setArgument:&value atIndex:2];
            break;
        }
        case LookinAttrTypeCGRect: {
            CGRect value = [(NSValue *)modification.value rectValue];
            [setterInvocation setArgument:&value atIndex:2];
            break;
        }
        case LookinAttrTypeUIColor: {
            NSColor *color = [NSColor lookin_colorFromRGBAComponents:modification.value];
            [setterInvocation setArgument:&color atIndex:2];
            [setterInvocation retainArguments];
            break;
        }
        default:
            completion(nil, LookinErr_Inner);
            return;
    }

    NSError *error = nil;
    @try {
        [setterInvocation invoke];
    } @catch (NSException *exception) {
        error = [NSError errorWithDomain:LookinErrorDomain code:LookinErrCode_Exception userInfo:@{
            NSLocalizedDescriptionKey: @"The modification may have failed.",
            NSLocalizedRecoverySuggestionErrorKey: exception.reason ?: @"Unknown exception."
        }];
    }

    LookinDisplayItemDetail *detail = [LookinDisplayItemDetail new];
    detail.displayItemOid = modification.targetOid;
    detail.attributesGroupList = [LKS_AttrGroupsMaker attrGroupsForLayer:receiver];
    detail.frameValue = [NSValue valueWithRect:receiver.frame];
    detail.boundsValue = [NSValue valueWithRect:receiver.bounds];
    detail.hiddenValue = @(receiver.hidden);
    detail.alphaValue = @(receiver.opacity);
    completion(detail, error);
}

+ (void)handlePatchWithTasks:(NSArray<LookinStaticAsyncUpdateTask *> *)tasks block:(void (^)(LookinDisplayItemDetail *data))block {
    if (!block) {
        return;
    }
    for (LookinStaticAsyncUpdateTask *task in tasks) {
        LookinDisplayItemDetail *detail = [LookinDisplayItemDetail new];
        detail.displayItemOid = task.oid;
        CALayer *layer = (CALayer *)[NSObject lks_objectWithOid:task.oid];
        if (![layer isKindOfClass:[CALayer class]]) {
            block(detail);
            continue;
        }
        if (task.taskType == LookinStaticAsyncUpdateTaskTypeSoloScreenshot) {
            detail.soloScreenshot = [layer lks_soloScreenshotWithLowQuality:NO];
        } else if (task.taskType == LookinStaticAsyncUpdateTaskTypeGroupScreenshot) {
            detail.groupScreenshot = [layer lks_groupScreenshotWithLowQuality:NO];
        }
        block(detail);
    }
}

@end

#else

#import "UIColor+LookinServer.h"
#import "LKS_CustomAttrGroupsMaker.h"

@implementation LKS_InbuiltAttrModificationHandler

+ (void)handleModification:(LookinAttributeModification *)modification completion:(void (^)(LookinDisplayItemDetail *data, NSError *error))completion {
    completion(nil, LookinErr_Inner);
}

+ (void)handlePatchWithTasks:(NSArray<LookinStaticAsyncUpdateTask *> *)tasks block:(void (^)(LookinDisplayItemDetail *data))block {
    if (!block) {
        return;
    }
    for (LookinStaticAsyncUpdateTask *task in tasks) {
        LookinDisplayItemDetail *detail = [LookinDisplayItemDetail new];
        detail.displayItemOid = task.oid;
        block(detail);
    }
}

@end

#endif

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
