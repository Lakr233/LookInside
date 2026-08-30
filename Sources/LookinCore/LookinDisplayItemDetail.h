#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  LookinDisplayItemDetail.h
//  Lookin
//
//  Created by Li Kai on 2019/2/19.
//  https://lookin.work
//

#import "LookinDefines.h"

@class LookinAttributesGroup;
@class LookinDisplayItem;

@interface LookinDisplayItemDetail : NSObject <NSSecureCoding>

@property(nonatomic, assign) unsigned long displayItemOid;

@property(nonatomic, strong) LookinImage *groupScreenshot;

@property(nonatomic, strong) LookinImage *soloScreenshot;

@property(nonatomic, strong) NSValue *frameValue;

@property(nonatomic, strong) NSValue *boundsValue;

@property(nonatomic, strong) NSNumber *hiddenValue;

@property(nonatomic, strong) NSNumber *alphaValue;

@property(nonatomic, copy) NSString *customDisplayTitle;

@property(nonatomic, copy) NSString *danceUISource;

@property(nonatomic, copy) NSArray<LookinAttributesGroup *> *attributesGroupList;
@property(nonatomic, copy) NSArray<LookinAttributesGroup *> *customAttrGroupList;

/// 注意 nil 和空数组的区别：nil 表示该属性无意义，空数组表示 subviews 为空
/// Client 1.0.7 & Server 1.2.7 开始支持该属性
/// 默认为 nil
@property(nonatomic, copy) NSArray<LookinDisplayItem *> *subitems;

/// 当 Server 找不到 task 对应的图层时，会返回一个特殊的 LookinDisplayItemDetail 对象，这个对象会被设置 displayItemOid 和 failureCode，其中 failureCode 会被置为 -1
/// Client 1.0.7 & Server 1.2.7 开始支持该属性
/// 默认为 0
@property(nonatomic, assign) NSInteger failureCode;

@end

/// Values of `failureCode`. The property stays a plain NSInteger on the wire.
typedef NS_ENUM(NSInteger, LookinDisplayItemDetailFailureCode) {
    LookinDisplayItemDetailFailureCodeNone = 0,
    /// The oid resolved to an object no detail branch handles — a real fault
    /// worth surfacing. The only value servers sent before 2026-08, so old
    /// hosts alert on exactly this one.
    LookinDisplayItemDetailFailureCodeUnhandledObject = -1,
    /// The oid resolved to nothing: the object was released after the
    /// hierarchy build. The inspected app's short-lived internals (TextKit 2
    /// fragment views, portals) go away on their own, so this is routine —
    /// the node keeps showing the data captured at build time and hosts log
    /// it without alerting. Old hosts treat it as a successful empty detail,
    /// which is harmless.
    LookinDisplayItemDetailFailureCodeObjectGone = -2,
};

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
