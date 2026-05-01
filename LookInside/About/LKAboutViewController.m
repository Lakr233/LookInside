//
//  LKAboutViewController.m
//  LookinClient
//
//  Created by 李凯 on 2019/10/30.
//  Copyright © 2019 hughkli. All rights reserved.
//

#import "LKAboutViewController.h"

static NSString * const kLookInsideUpstreamURL = @"https://github.com/QMUI/LookinServer";
static NSString * const kLookInsideHomeURL = @"https://lookinside-app.com";

@interface LKAboutViewController ()

@property(nonatomic, strong) LKBaseView *backgroundImageView;
@property(nonatomic, strong) LKBaseView *paperOverlayView;
@property(nonatomic, strong) NSImageView *iconImageView;
@property(nonatomic, strong) LKLabel *titleLabel;
@property(nonatomic, strong) LKLabel *versionLabel;
@property(nonatomic, strong) LKLabel *taglineLabel;
@property(nonatomic, strong) NSStackView *contentStackView;
@property(nonatomic, strong) NSTextView *legalTextView;

@end

@implementation LKAboutViewController

- (NSView *)makeContainerView {
    LKBaseView *containerView = [LKBaseView new];
    containerView.backgroundColors = LKColorsCombine(
        [NSColor colorWithCalibratedRed:0.99 green:0.97 blue:0.93 alpha:1],
        [NSColor colorWithCalibratedWhite:0.10 alpha:1]);

    self.backgroundImageView = [LKBaseView new];
    self.backgroundImageView.wantsLayer = YES;
    self.backgroundImageView.layer.contents = NSImageMake(@"aboutHeroBg");
    self.backgroundImageView.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.backgroundImageView.layer.masksToBounds = YES;
    self.backgroundImageView.layer.opacity = 0.25;
    [containerView addSubview:self.backgroundImageView];

    self.paperOverlayView = [LKBaseView new];
    self.paperOverlayView.backgroundColors = LKColorsCombine(
        [NSColor colorWithCalibratedRed:0.99 green:0.97 blue:0.93 alpha:0.55],
        [NSColor colorWithCalibratedWhite:0.10 alpha:0.55]);
    [containerView addSubview:self.paperOverlayView];

    self.iconImageView = [NSImageView new];
    self.iconImageView.image = [NSApp applicationIconImage];
    self.iconImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [self.iconImageView.widthAnchor constraintEqualToConstant:96].active = YES;
    [self.iconImageView.heightAnchor constraintEqualToConstant:96].active = YES;

    NSFontDescriptor *serifDescriptor = [[NSFontDescriptor fontDescriptorWithFontAttributes:@{}]
        fontDescriptorWithDesign:NSFontDescriptorSystemDesignSerif];
    NSFont *titleFont = [NSFont fontWithDescriptor:serifDescriptor size:30] ?: [NSFont systemFontOfSize:30 weight:NSFontWeightRegular];
    NSFont *footnoteFont = [NSFont preferredFontForTextStyle:NSFontTextStyleFootnote options:@{}];

    self.titleLabel = [LKLabel new];
    self.titleLabel.stringValue = @"LookInside";
    self.titleLabel.textColors = LKColorsCombine([NSColor colorWithCalibratedWhite:0.12 alpha:1],
                                                  [NSColor colorWithCalibratedWhite:0.96 alpha:1]);
    self.titleLabel.font = titleFont;

    NSString *dotVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *numberVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    self.versionLabel = [LKLabel new];
    self.versionLabel.stringValue = [NSString stringWithFormat:@"Version %@ (%@)", dotVersion, numberVersion];
    self.versionLabel.textColors = LKColorsCombine([NSColor colorWithCalibratedWhite:0.35 alpha:1],
                                                    [NSColor colorWithCalibratedWhite:0.78 alpha:1]);
    self.versionLabel.font = footnoteFont;

    self.taglineLabel = [LKLabel new];
    self.taglineLabel.stringValue = @"A SwiftUI- and UIKit-aware view debugger.\nWalk every layer. Read every modifier.";
    self.taglineLabel.textColors = LKColorsCombine([NSColor colorWithCalibratedWhite:0.30 alpha:1],
                                                    [NSColor colorWithCalibratedWhite:0.82 alpha:1]);
    self.taglineLabel.font = footnoteFont;
    self.taglineLabel.alignment = NSTextAlignmentCenter;
    self.taglineLabel.maximumNumberOfLines = 2;

    self.contentStackView = [NSStackView stackViewWithViews:@[
        self.iconImageView, self.titleLabel, self.versionLabel, self.taglineLabel
    ]];
    self.contentStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.contentStackView.alignment = NSLayoutAttributeCenterX;
    self.contentStackView.spacing = 16;
    [containerView addSubview:self.contentStackView];

    self.legalTextView = [[NSTextView alloc] initWithFrame:NSZeroRect];
    self.legalTextView.editable = NO;
    self.legalTextView.selectable = YES;
    self.legalTextView.drawsBackground = NO;
    self.legalTextView.textContainerInset = NSZeroSize;
    self.legalTextView.textContainer.lineFragmentPadding = 0;
    self.legalTextView.linkTextAttributes = @{
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.40 green:0.32 blue:0.62 alpha:1],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        NSCursorAttributeName: [NSCursor pointingHandCursor]
    };

    NSMutableParagraphStyle *legalParagraph = [[NSMutableParagraphStyle alloc] init];
    legalParagraph.alignment = NSTextAlignmentCenter;
    legalParagraph.lineSpacing = 2;

    NSColor *legalColor = [NSColor colorWithCalibratedWhite:0.40 alpha:1];
    NSDictionary *legalAttrs = @{
        NSFontAttributeName: footnoteFont,
        NSForegroundColorAttributeName: legalColor,
        NSParagraphStyleAttributeName: legalParagraph
    };
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger year = [calendar component:NSCalendarUnitYear fromDate:[NSDate date]];

    NSMutableAttributedString *legal = [[NSMutableAttributedString alloc] init];
    [legal appendAttributedString:[[NSAttributedString alloc] initWithString:
        [NSString stringWithFormat:@"© %ld LookInside-App. Released under GPL-3.0.\n", (long)year]
                                                                attributes:legalAttrs]];
    [legal appendAttributedString:[[NSAttributedString alloc] initWithString:@"Based on " attributes:legalAttrs]];
    [legal appendAttributedString:[[NSAttributedString alloc] initWithString:@"Lookin" attributes:legalAttrs]];
    [legal addAttribute:NSLinkAttributeName value:kLookInsideUpstreamURL
                  range:NSMakeRange(legal.length - 6, 6)];
    [legal appendAttributedString:[[NSAttributedString alloc] initWithString:@" by QMUI · " attributes:legalAttrs]];
    [legal appendAttributedString:[[NSAttributedString alloc] initWithString:@"lookinside-app.com" attributes:legalAttrs]];
    [legal addAttribute:NSLinkAttributeName value:kLookInsideHomeURL
                  range:NSMakeRange(legal.length - 18, 18)];

    [self.legalTextView.textStorage setAttributedString:legal];
    [containerView addSubview:self.legalTextView];

    return containerView;
}

- (void)viewDidLayout {
    [super viewDidLayout];
    static const CGFloat kPad = 16;
    $(self.backgroundImageView, self.paperOverlayView).fullFrame;

    NSSize legalSize = [self.legalTextView.attributedString
        boundingRectWithSize:NSMakeSize(self.view.$width - kPad * 2, CGFLOAT_MAX)
                     options:NSStringDrawingUsesLineFragmentOrigin].size;
    CGFloat legalHeight = ceil(legalSize.height) + 4;
    CGFloat legalY = self.view.$height - kPad - legalHeight;
    $(self.legalTextView).width(self.view.$width - kPad * 2).height(legalHeight).horAlign.y(legalY);

    NSSize stackSize = [self.contentStackView fittingSize];
    CGFloat available = legalY - kPad - kPad;
    CGFloat stackY = kPad + MAX(0, (available - stackSize.height) / 2.0);
    $(self.contentStackView).width(stackSize.width).height(stackSize.height).horAlign.y(stackY);
}

@end
