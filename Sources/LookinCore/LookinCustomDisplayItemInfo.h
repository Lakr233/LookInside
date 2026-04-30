#ifdef SHOULD_COMPILE_LOOKIN_SERVER
//
//  LookinCustomDisplayItemInfo.h
//  LookinServer
//
//  Created by likai.123 on 2023/11/1.
//

#import <Foundation/Foundation.h>

@interface LookinCustomDisplayItemInfo : NSObject <NSSecureCoding, NSCopying>

/// 该属性可能有值（CGRect）也可能是 nil（nil 时则表示无图像）
@property(nonatomic, strong) NSValue *frameInWindow;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subtitle;
@property(nonatomic, copy) NSString *danceuiSource;

/// YES if this display item represents a SwiftUI virtual node produced by the
/// activation-gated SwiftUI extension. Hosts use this to render an accent
/// indicating paid-feature data.
@property(nonatomic, assign) BOOL isSwiftUI;

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
