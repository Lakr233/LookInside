//
//  LookinDocument.m
//  Lookin
//
//  Created by Li Kai on 2019/6/26.
//  https://lookin.work
//

#import "LookinDocument.h"
#import "LookinHierarchyFile.h"
#import "LKReadWindowController.h"
#import "LKNavigationManager.h"

// 点击 menu 里的 “打开文件” 会走到这里的一系列方法
@implementation LookinDocument

- (void)makeWindowControllers {
    LKReadWindowController *wc = [[LKReadWindowController alloc] initWithFile:self.hierarchyFile];
    [self addWindowController:wc];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    if (!self.hierarchyFile) {
        NSAssert(NO, @"");
        if (outError) {
            *outError = LookinErr_Inner;
        }
        return nil;
    }
    
    if ([typeName isEqualToString:@"com.lookin.lookin"]) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.hierarchyFile requiringSecureCoding:YES error:outError];
        return data;
    }
    
    if (outError) {
        *outError = LookinErr_Inner;
    }
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // .lookin archives are non-secure NSKeyedArchiver payloads holding LookinHierarchyFile graphs.
    // Stay on the legacy API to avoid the NSSecureCoding "[NSObject class] allowed list" runtime spam.
    LookinHierarchyFile *hierarchyFile = [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
    if (!hierarchyFile) {
        if (outError) {
            *outError = LookinErr_Inner;
        }
        return NO;
    }
    
    NSError *verifyError = [LookinHierarchyFile verifyHierarchyFile:hierarchyFile];
    if (verifyError) {
        if (outError) {
            *outError = verifyError;
        }
        return NO;
    }

    self.hierarchyFile = hierarchyFile;
    return YES;
}

@end
