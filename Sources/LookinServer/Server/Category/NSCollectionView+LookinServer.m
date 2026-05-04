#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && TARGET_OS_OSX
//
//  NSCollectionView+LookinServer.m
//  LookinServer
//
//  Created by JH on 2026/5/4.
//

#import "NSCollectionView+LookinServer.h"

static NSString *LKSStringFromColor(NSColor *color) {
    NSColor *rgbColor = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if (!rgbColor) {
        return color.description;
    }

    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 0;
    [rgbColor getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"rgba(%.3f, %.3f, %.3f, %.3f)", red, green, blue, alpha];
}

@implementation NSCollectionView (LookinServer)

- (NSString *)lks_backgroundColorsDescription {
    NSArray<NSColor *> *backgroundColors = self.backgroundColors;
    if (backgroundColors.count == 0) {
        return @"[]";
    }

    NSMutableArray<NSString *> *colorDescriptions = [NSMutableArray arrayWithCapacity:backgroundColors.count];
    [backgroundColors enumerateObjectsUsingBlock:^(NSColor * _Nonnull color, NSUInteger index, BOOL * _Nonnull stop) {
        [colorDescriptions addObject:LKSStringFromColor(color)];
    }];
    return [colorDescriptions componentsJoinedByString:@", "];
}

@end

#endif
