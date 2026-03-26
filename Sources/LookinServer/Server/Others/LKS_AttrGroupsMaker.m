#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && (TARGET_OS_IPHONE || TARGET_OS_TV || TARGET_OS_VISION || TARGET_OS_MAC)
//
//  LKS_AttrGroupsMaker.m
//  LookinServer
//
//  Created by Li Kai on 2019/6/6.
//  https://lookin.work
//

#import "LKS_AttrGroupsMaker.h"
#import "LookinAttributesGroup.h"
#import "LookinAttributesSection.h"
#import "LookinAttribute.h"
#import "LookinDashboardBlueprint.h"
#import "CALayer+LookinServer.h"

#if TARGET_OS_MAC
#import "Color+Lookin.h"

@implementation LKS_AttrGroupsMaker

+ (LookinAttribute *)_attributeWithID:(LookinAttrIdentifier)identifier type:(LookinAttrType)type value:(id)value {
    LookinAttribute *attribute = [LookinAttribute new];
    attribute.identifier = identifier;
    attribute.attrType = type;
    attribute.value = value;
    return attribute;
}

+ (LookinAttributesSection *)_sectionWithID:(LookinAttrSectionIdentifier)identifier attrs:(NSArray<LookinAttribute *> *)attrs {
    NSArray<LookinAttribute *> *validAttrs = [attrs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LookinAttribute *attribute, NSDictionary<NSString *, id> *bindings) {
        return attribute != nil;
    }]];
    if (!validAttrs.count) {
        return nil;
    }
    LookinAttributesSection *section = [LookinAttributesSection new];
    section.identifier = identifier;
    section.attributes = validAttrs;
    return section;
}

+ (LookinAttributesGroup *)_groupWithID:(LookinAttrGroupIdentifier)identifier sections:(NSArray<LookinAttributesSection *> *)sections {
    NSArray<LookinAttributesSection *> *validSections = [sections filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LookinAttributesSection *section, NSDictionary<NSString *, id> *bindings) {
        return section != nil;
    }]];
    if (!validSections.count) {
        return nil;
    }
    LookinAttributesGroup *group = [LookinAttributesGroup new];
    group.identifier = identifier;
    group.attrSections = validSections;
    return group;
}

+ (NSArray<LookinAttributesGroup *> *)attrGroupsForLayer:(CALayer *)layer {
    if (!layer) {
        return @[];
    }

    NSMutableArray<LookinAttributesGroup *> *groups = [NSMutableArray array];

    LookinAttributesGroup *classGroup = [self _groupWithID:LookinAttrGroup_Class sections:@[
        [self _sectionWithID:LookinAttrSec_Class_Class attrs:@[
            [self _attributeWithID:LookinAttr_Class_Class_Class type:LookinAttrTypeCustomObj value:[layer lks_relatedClassChainList]]
        ]]
    ]];
    if (classGroup) {
        [groups addObject:classGroup];
    }

    NSArray<NSString *> *relation = [layer lks_selfRelation];
    LookinAttributesGroup *relationGroup = [self _groupWithID:LookinAttrGroup_Relation sections:@[
        [self _sectionWithID:LookinAttrSec_Relation_Relation attrs:@[
            [self _attributeWithID:LookinAttr_Relation_Relation_Relation type:LookinAttrTypeCustomObj value:relation]
        ]]
    ]];
    if (relationGroup) {
        [groups addObject:relationGroup];
    }

    LookinAttributesGroup *layoutGroup = [self _groupWithID:LookinAttrGroup_Layout sections:@[
        [self _sectionWithID:LookinAttrSec_Layout_Frame attrs:@[
            [self _attributeWithID:LookinAttr_Layout_Frame_Frame type:LookinAttrTypeCGRect value:[NSValue valueWithRect:layer.frame]]
        ]],
        [self _sectionWithID:LookinAttrSec_Layout_Bounds attrs:@[
            [self _attributeWithID:LookinAttr_Layout_Bounds_Bounds type:LookinAttrTypeCGRect value:[NSValue valueWithRect:layer.bounds]]
        ]],
        [self _sectionWithID:LookinAttrSec_Layout_Position attrs:@[
            [self _attributeWithID:LookinAttr_Layout_Position_Position type:LookinAttrTypeCGPoint value:[NSValue valueWithPoint:layer.position]]
        ]],
        [self _sectionWithID:LookinAttrSec_Layout_AnchorPoint attrs:@[
            [self _attributeWithID:LookinAttr_Layout_AnchorPoint_AnchorPoint type:LookinAttrTypeCGPoint value:[NSValue valueWithPoint:layer.anchorPoint]]
        ]]
    ]];
    if (layoutGroup) {
        [groups addObject:layoutGroup];
    }

    NSColor *backgroundColor = layer.lks_backgroundColor;
    NSColor *borderColor = layer.lks_borderColor;
    NSColor *shadowColor = layer.lks_shadowColor;
    LookinAttributesGroup *viewLayerGroup = [self _groupWithID:LookinAttrGroup_ViewLayer sections:@[
        [self _sectionWithID:LookinAttrSec_ViewLayer_Visibility attrs:@[
            [self _attributeWithID:LookinAttr_ViewLayer_Visibility_Hidden type:LookinAttrTypeBOOL value:@(layer.hidden)],
            [self _attributeWithID:LookinAttr_ViewLayer_Visibility_Opacity type:LookinAttrTypeFloat value:@(layer.opacity)]
        ]],
        [self _sectionWithID:LookinAttrSec_ViewLayer_InterationAndMasks attrs:@[
            [self _attributeWithID:LookinAttr_ViewLayer_InterationAndMasks_MasksToBounds type:LookinAttrTypeBOOL value:@(layer.masksToBounds)]
        ]],
        [self _sectionWithID:LookinAttrSec_ViewLayer_Corner attrs:@[
            [self _attributeWithID:LookinAttr_ViewLayer_Corner_Radius type:LookinAttrTypeDouble value:@(layer.cornerRadius)]
        ]],
        [self _sectionWithID:LookinAttrSec_ViewLayer_BgColor attrs:@[
            [self _attributeWithID:LookinAttr_ViewLayer_BgColor_BgColor type:LookinAttrTypeUIColor value:backgroundColor ? backgroundColor.lookin_rgbaComponents : nil]
        ]],
        [self _sectionWithID:LookinAttrSec_ViewLayer_Border attrs:@[
            [self _attributeWithID:LookinAttr_ViewLayer_Border_Color type:LookinAttrTypeUIColor value:borderColor ? borderColor.lookin_rgbaComponents : nil],
            [self _attributeWithID:LookinAttr_ViewLayer_Border_Width type:LookinAttrTypeDouble value:@(layer.borderWidth)]
        ]],
        [self _sectionWithID:LookinAttrSec_ViewLayer_Shadow attrs:@[
            [self _attributeWithID:LookinAttr_ViewLayer_Shadow_Color type:LookinAttrTypeUIColor value:shadowColor ? shadowColor.lookin_rgbaComponents : nil],
            [self _attributeWithID:LookinAttr_ViewLayer_Shadow_Opacity type:LookinAttrTypeFloat value:@(layer.shadowOpacity)],
            [self _attributeWithID:LookinAttr_ViewLayer_Shadow_Radius type:LookinAttrTypeDouble value:@(layer.shadowRadius)],
            [self _attributeWithID:LookinAttr_ViewLayer_Shadow_OffsetW type:LookinAttrTypeDouble value:@(layer.shadowOffset.width)],
            [self _attributeWithID:LookinAttr_ViewLayer_Shadow_OffsetH type:LookinAttrTypeDouble value:@(layer.shadowOffset.height)]
        ]]
    ]];
    if (viewLayerGroup) {
        [groups addObject:viewLayerGroup];
    }

    return groups.copy;
}

@end

#else

#import "NSArray+Lookin.h"
#import "LookinIvarTrace.h"
#import "UIColor+LookinServer.h"
#import "LookinServerDefines.h"

@implementation LKS_AttrGroupsMaker

+ (NSArray<LookinAttributesGroup *> *)attrGroupsForLayer:(CALayer *)layer {
    if (!layer) {
        NSAssert(NO, @"");
        return nil;
    }
    NSArray<LookinAttributesGroup *> *groups = [[LookinDashboardBlueprint groupIDs] lookin_map:^id(NSUInteger idx, LookinAttrGroupIdentifier groupID) {
        LookinAttributesGroup *group = [LookinAttributesGroup new];
        group.identifier = groupID;

        NSArray<LookinAttrSectionIdentifier> *secIDs = [LookinDashboardBlueprint sectionIDsForGroupID:groupID];
        group.attrSections = [secIDs lookin_map:^id(NSUInteger idx, LookinAttrSectionIdentifier secID) {
            LookinAttributesSection *sec = [LookinAttributesSection new];
            sec.identifier = secID;
            
            NSArray<LookinAttrIdentifier> *attrIDs = [LookinDashboardBlueprint attrIDsForSectionID:secID];
            sec.attributes = [attrIDs lookin_map:^id(NSUInteger idx, LookinAttrIdentifier attrID) {
                NSInteger minAvailableVersion = [LookinDashboardBlueprint minAvailableOSVersionWithAttrID:attrID];
                if (minAvailableVersion > 0 && (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < minAvailableVersion)) {
                    return nil;
                }
                
                id targetObj = nil;
                if ([LookinDashboardBlueprint isUIViewPropertyWithAttrID:attrID]) {
                    targetObj = layer.lks_hostView;
                } else {
                    targetObj = layer;
                }
                
                if (targetObj) {
                    Class targetClass = NSClassFromString([LookinDashboardBlueprint classNameWithAttrID:attrID]);
                    if (![targetObj isKindOfClass:targetClass]) {
                        return nil;
                    }
                    
                    LookinAttribute *attr = [self _attributeWithIdentifer:attrID targetObject:targetObj];
                    return attr;
                } else {
                    return nil;
                }
            }];
            
            if (sec.attributes.count) {
                return sec;
            } else {
                return nil;
            }
        }];
        
        if ([groupID isEqualToString:LookinAttrGroup_AutoLayout]) {
            BOOL hasConstraits = [group.attrSections lookin_any:^BOOL(LookinAttributesSection *obj) {
                return [obj.identifier isEqualToString:LookinAttrSec_AutoLayout_Constraints];
            }];
            if (!hasConstraits) {
                return nil;
            }
        }
        
        if (group.attrSections.count) {
            return group;
        } else {
            return nil;
        }
    }];
    
    return groups;
}

+ (LookinAttribute *)_attributeWithIdentifer:(LookinAttrIdentifier)identifier targetObject:(id)target {
    if (!target) {
        NSAssert(NO, @"");
        return nil;
    }
    
    LookinAttribute *attribute = [LookinAttribute new];
    attribute.identifier = identifier;
    
    SEL getter = [LookinDashboardBlueprint getterWithAttrID:identifier];
    if (!getter) {
        NSAssert(NO, @"");
        return nil;
    }
    if (![target respondsToSelector:getter]) {
        return nil;
    }
    NSMethodSignature *signature = [target methodSignatureForSelector:getter];
    if (signature.numberOfArguments > 2) {
        NSAssert(NO, @"getter 不可以有参数");
        return nil;
    }
    if (strcmp([signature methodReturnType], @encode(void)) == 0) {
        NSAssert(NO, @"getter 返回值不能为 void");
        return nil;
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = getter;
    [invocation invoke];
    
    const char *returnType = [signature methodReturnType];
    
    if (strcmp(returnType, @encode(char)) == 0) {
        char targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeChar;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(int)) == 0) {
        int targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.value = @(targetValue);
        attribute.attrType = [LookinDashboardBlueprint enumListNameWithAttrID:identifier] ? LookinAttrTypeEnumInt : LookinAttrTypeInt;
    } else if (strcmp(returnType, @encode(short)) == 0) {
        short targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeShort;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(long)) == 0) {
        long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.value = @(targetValue);
        attribute.attrType = [LookinDashboardBlueprint enumListNameWithAttrID:identifier] ? LookinAttrTypeEnumLong : LookinAttrTypeLong;
    } else if (strcmp(returnType, @encode(long long)) == 0) {
        long long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeLongLong;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(unsigned char)) == 0) {
        unsigned char targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedChar;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(unsigned int)) == 0) {
        unsigned int targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedInt;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(unsigned short)) == 0) {
        unsigned short targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedShort;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(unsigned long)) == 0) {
        unsigned long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedLong;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
        unsigned long long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedLongLong;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(float)) == 0) {
        float targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeFloat;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(double)) == 0) {
        double targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeDouble;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(BOOL)) == 0) {
        BOOL targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeBOOL;
        attribute.value = @(targetValue);
    } else if (strcmp(returnType, @encode(CGPoint)) == 0) {
        CGPoint targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGPoint;
        attribute.value = [NSValue valueWithCGPoint:targetValue];
    } else if (strcmp(returnType, @encode(CGSize)) == 0) {
        CGSize targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGSize;
        attribute.value = [NSValue valueWithCGSize:targetValue];
    } else if (strcmp(returnType, @encode(CGRect)) == 0) {
        CGRect targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGRect;
        attribute.value = [NSValue valueWithCGRect:targetValue];
    } else {
        NSString *argTypeString = [[NSString alloc] lookin_safeInitWithUTF8String:returnType];
        if ([argTypeString hasPrefix:@"@"]) {
            __unsafe_unretained id returnObjValue;
            [invocation getReturnValue:&returnObjValue];
            if (!returnObjValue && [LookinDashboardBlueprint hideIfNilWithAttrID:identifier]) {
                return nil;
            }
            attribute.attrType = [LookinDashboardBlueprint objectAttrTypeWithAttrID:identifier];
            if (attribute.attrType == LookinAttrTypeUIColor) {
                attribute.value = returnObjValue ? [returnObjValue lks_rgbaComponents] : nil;
            } else {
                attribute.value = returnObjValue;
            }
        } else {
            return nil;
        }
    }
    
    return attribute;
}

@end

#endif

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
