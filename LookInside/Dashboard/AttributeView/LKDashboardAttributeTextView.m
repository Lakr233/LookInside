//
//  LKDashboardAttributeTextView.m
//  Lookin
//
//  Created by Li Kai on 2019/9/16.
//  https://lookin.work
//

#import "LKDashboardAttributeTextView.h"
#import "LKDashboardViewController.h"
#import "LookinDashboardBlueprint.h"

@interface LKDashboardAttributeTextView () <NSTextViewDelegate>

@property(nonatomic, strong) LKLabel *titleLabel;
@property(nonatomic, strong) NSScrollView *scrollView;
@property(nonatomic, strong) NSTextView *textView;

@property(nonatomic, copy) NSString *initialText;

@end

@implementation LKDashboardAttributeTextView

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        self.initialText = @"";

        self.layer.cornerRadius = DashboardCardControlCornerRadius;

        self.titleLabel = [LKLabel new];
        self.titleLabel.textColor = [NSColor colorNamed:@"DashboardInputAccessoryColor"];
        self.titleLabel.font = NSFontMake(10);
        self.titleLabel.maximumNumberOfLines = 1;
        self.titleLabel.hidden = YES;
        [self addSubview:self.titleLabel];

        self.scrollView = [LKHelper scrollableTextView];
        self.scrollView.drawsBackground = NO;
        self.scrollView.hasVerticalScroller = NO;
        self.scrollView.hasHorizontalScroller = NO;
        self.textView = self.scrollView.documentView;
        self.textView.font = NSFontMake(12);
        self.textView.drawsBackground = NO;
        self.textView.textContainerInset = NSMakeSize(2, 4);
        self.textView.delegate = self;
        [self addSubview:self.scrollView];
    }
    return self;
}

- (void)layout {
    [super layout];
    if (self.titleLabel.isHidden) {
        $(self.scrollView).fullFrame;
    } else {
        CGFloat titleHeight = [self.titleLabel sizeThatFits:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)].height;
        $(self.titleLabel).x(7).toRight(7).heightToFit.y(4);
        CGFloat scrollY = 4 + titleHeight + 1;
        $(self.scrollView).x(0).toRight(0).y(scrollY).toBottom(0);
    }
}

- (void)renderWithAttribute {
    [super renderWithAttribute];

    // Show title label for non-custom attributes
    if (!self.attribute.isUserCustom) {
        NSString *briefTitle = [LookinDashboardBlueprint briefTitleWithAttrID:self.attribute.identifier];
        if (briefTitle.length > 0) {
            self.titleLabel.stringValue = briefTitle;
            self.titleLabel.hidden = NO;
        } else {
            self.titleLabel.hidden = YES;
        }
    } else {
        self.titleLabel.hidden = YES;
    }

    /// nil 居然会 crash
    self.initialText = self.attribute.value ? : @"";
    self.textView.string = self.initialText;
    self.textView.editable = self.canEdit;
}

- (NSSize)sizeThatFits:(NSSize)limitedSize {
    limitedSize.width -= self.textView.textContainerInset.width * 2;

    NSDictionary *attributes = @{NSFontAttributeName: self.textView.font};
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[self.textView string] attributes:attributes];
    NSRect rect = [attributedString boundingRectWithSize:limitedSize options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    CGFloat contentHeight = rect.size.height + self.textView.textContainerInset.height * 2;
    CGFloat textHeight = MIN(MAX(contentHeight, 24), 80);

    if (!self.titleLabel.isHidden) {
        CGFloat titleHeight = [self.titleLabel sizeThatFits:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)].height;
        textHeight += 3 + titleHeight + 1;
    }

    limitedSize.height = textHeight;
    return limitedSize;
}

- (void)setDashboardViewController:(LKDashboardViewController *)dashboardViewController {
    [super setDashboardViewController:dashboardViewController];
    self.backgroundColorName = @"DashboardCardValueBGColor";
}

#pragma mark - <NSTextViewDelegate>

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        [self.window makeFirstResponder:nil];
        return YES;
    }
    return NO;
}

- (void)textDidEndEditing:(NSNotification *)notification {
    NSString *expectedValue = self.textView.string;

    if ([expectedValue isEqual:self.initialText]) {
        NSLog(@"修改没有变化，不做任何提交");
        [self renderWithAttribute];
        return;
    }

    // 提交修改
    @weakify(self);
    [[self.dashboardViewController modifyAttribute:self.attribute newValue:expectedValue] subscribeError:^(NSError * _Nullable error) {
        @strongify(self);
        NSLog(@"修改返回 error");
        [self renderWithAttribute];
    }];
}

@end
