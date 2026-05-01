#ifdef SHOULD_COMPILE_LOOKIN_SERVER
//
//  LookinCustomDisplayItemInfo.h
//  LookinServer
//
//  Created by likai.123 on 2023/11/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LookinCustomDisplayItemInfo : NSObject <NSSecureCoding, NSCopying>

/// 该属性可能有值（CGRect）也可能是 nil（nil 时则表示无图像）
@property(nonatomic, strong, nullable) NSValue *frameInWindow;
@property(nonatomic, copy, nullable) NSString *title;
@property(nonatomic, copy, nullable) NSString *subtitle;
@property(nonatomic, copy, nullable) NSString *danceuiSource;

/// YES if this display item represents a SwiftUI virtual node produced by the
/// activation-gated SwiftUI extension. Hosts use this to render an accent
/// indicating paid-feature data.
@property(nonatomic, assign) BOOL isSwiftUI;

/// 由 server 端生成的 SwiftUI 节点稳定 ID。仅当 isSwiftUI=YES 时有值,
/// 形如 `swiftui:<host>:<preOrderIndex>`。compact / verbose 共享同一编号
/// 空间, host 用它做 mode 切换时的 selection / scroll restore。详见 spec
/// §ID 稳定性 + §Wire 协议 (spec 显式标注此字段为 `nullable`)。
@property(nonatomic, copy, nullable) NSString *swiftUIDisplayItemID;

@end

NS_ASSUME_NONNULL_END

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
