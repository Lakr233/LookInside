//
//  LKPreferenceViewController.m
//  Lookin
//
//  Created by Li Kai on 2019/1/4.
//  https://lookin.work
//

#import "LKPreferenceViewController.h"
#import "LKPreferenceManager.h"
#import "LKPreferencePopupView.h"
#import "LKNavigationManager.h"
#import "LKMessageManager.h"

@interface LKPreferenceNumberInputView : LKBaseView <NSTextFieldDelegate>

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message;

@property(nonatomic, assign) CGFloat buttonX;
@property(nonatomic, assign) double doubleValue;
@property(nonatomic, copy) void (^didChange)(double doubleValue);

@end

@interface LKPreferenceNumberInputView ()

@property(nonatomic, strong) LKLabel *titleLabel;
@property(nonatomic, strong) NSTextField *textField;
@property(nonatomic, strong) LKLabel *messageLabel;

@end

@implementation LKPreferenceNumberInputView

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message {
    if (self = [self initWithFrame:NSZeroRect]) {
        self.titleLabel = [LKLabel new];
        self.titleLabel.stringValue = title;
        self.titleLabel.font = NSFontMake(IsEnglish ? 13 : 15);
        [self addSubview:self.titleLabel];

        self.textField = [NSTextField new];
        self.textField.font = NSFontMake(IsEnglish ? 13 : 14);
        self.textField.alignment = NSTextAlignmentRight;
        self.textField.delegate = self;
        [self addSubview:self.textField];

        self.messageLabel = [LKLabel new];
        self.messageLabel.stringValue = message;
        self.messageLabel.font = NSFontMake(IsEnglish ? 12 : 13);
        self.messageLabel.textColor = [NSColor secondaryLabelColor];
        self.messageLabel.maximumNumberOfLines = 0;
        [self addSubview:self.messageLabel];
    }
    return self;
}

- (void)layout {
    [super layout];
    CGFloat textFieldHeight = [self.textField sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].height + 2;
    $(self.textField).width(90).height(textFieldHeight).x(self.buttonX).y(0);
    $(self.messageLabel).x(self.textField.$x).toRight(0).y(self.textField.$maxY + 4).toBottom(0);
    $(self.titleLabel).sizeToFit.maxX(self.buttonX - 3).y(0);
}

- (void)setButtonX:(CGFloat)buttonX {
    _buttonX = buttonX;
    [self setNeedsLayout:YES];
}

- (void)setDoubleValue:(double)doubleValue {
    _doubleValue = doubleValue;
    self.textField.stringValue = [self _displayStringFromDouble:doubleValue];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    [self _commitTextField];
}

- (void)_commitTextField {
    NSString *inputString = [self.textField.stringValue ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSScanner *scanner = [NSScanner scannerWithString:inputString];
    double newValue = 0;
    BOOL didScan = [scanner scanDouble:&newValue];
    if (didScan && scanner.isAtEnd && newValue > 0) {
        self.doubleValue = newValue;
        if (self.didChange) {
            self.didChange(newValue);
        }
    } else {
        self.textField.stringValue = [self _displayStringFromDouble:self.doubleValue];
    }
}

- (NSString *)_displayStringFromDouble:(double)value {
    NSString *string = [NSString stringWithFormat:@"%.2f", value];
    while ([string containsString:@"."] && [string hasSuffix:@"0"]) {
        string = [string substringToIndex:string.length - 1];
    }
    if ([string hasSuffix:@"."]) {
        string = [string substringToIndex:string.length - 1];
    }
    return string;
}

@end

@interface LKPreferenceViewController ()

@property(nonatomic, strong) LKPreferencePopupView *view_doubleClick;
@property(nonatomic, strong) LKPreferencePopupView *view_appearance;
@property(nonatomic, strong) LKPreferencePopupView *view_colorFormat;
@property(nonatomic, strong) LKPreferencePopupView *view_contrast;
@property(nonatomic, strong) LKPreferenceNumberInputView *view_hierarchyTimeout;
#if DEBUG
@property(nonatomic, strong) LKPreferenceNumberInputView *view_licenseTimeout;
#endif

//@property(nonatomic, strong) NSButton *debugButton;
@property(nonatomic, strong) NSButton *resetButton;

@end

@implementation LKPreferenceViewController

- (void)setView:(NSView *)view {
    [super setView:view];
    
    CGFloat controlX = IsEnglish ? 94 : 84;
    
//    LKPreferenceManager *manager = [LKPreferenceManager mainManager];
//    
//    @weakify(self);
    self.view_colorFormat = [[LKPreferencePopupView alloc] initWithTitle:NSLocalizedString(@"Color Format", nil) messages:@[NSLocalizedString(@"Color will be displayed in format like (255, 12, 34, 0.5). Alpha value is between 0 and 1.", nil), NSLocalizedString(@"Color will be displayed in format like #7e7e7eff. The components are #RRGGBBAA.", nil)] options:@[@"RGBA", @"HEX"]];
    self.view_colorFormat.buttonX = controlX;
    self.view_colorFormat.didChange = ^(NSUInteger selectedIndex) {
        [LKPreferenceManager mainManager].rgbaFormat = (selectedIndex == 0 ? YES : NO);
    };
    [self.view addSubview:self.view_colorFormat];
    
    NSString *contrastTips = NSLocalizedString(@"Adjust this option to use a deeper layer selection color.", nil);
    self.view_contrast = [[LKPreferencePopupView alloc] initWithTitle:NSLocalizedString(@"Image contrast", nil) messages:@[contrastTips, contrastTips, contrastTips] options:@[NSLocalizedString(@"Normal", nil), NSLocalizedString(@"Medium", nil), NSLocalizedString(@"High", nil)]];
    self.view_contrast.buttonX = controlX;
    self.view_contrast.didChange = ^(NSUInteger selectedIndex) {
        [LKPreferenceManager mainManager].imageContrastLevel = selectedIndex;
    };
    [self.view addSubview:self.view_contrast];
    
    self.view_appearance = [[LKPreferencePopupView alloc] initWithTitle:NSLocalizedString(@"Appearance", nil) message:nil options:@[NSLocalizedString(@"Dark Mode", nil), NSLocalizedString(@"Light Mode", nil), NSLocalizedString(@"System Default", nil)]];
    self.view_appearance.buttonX = controlX;
    self.view_appearance.didChange = ^(NSUInteger selectedIndex) {
        [LKPreferenceManager mainManager].appearanceType = selectedIndex;
    };
    [self.view addSubview:self.view_appearance];
    
    self.view_doubleClick = [[LKPreferencePopupView alloc] initWithTitle:NSLocalizedString(@"Double click", nil) message:nil options:@[NSLocalizedString(@"Expand or collapse layer", nil), NSLocalizedString(@"Focus on layer", nil)]];
    self.view_doubleClick.buttonX = controlX;
    self.view_doubleClick.didChange = ^(NSUInteger selectedIndex) {
        [LKPreferenceManager mainManager].doubleClickBehavior = selectedIndex;
    };
    [self.view addSubview:self.view_doubleClick];

    self.view_hierarchyTimeout = [[LKPreferenceNumberInputView alloc] initWithTitle:NSLocalizedString(@"Hierarchy Timeout", nil) message:NSLocalizedString(@"Timeout for hierarchy and hierarchy-details requests, in seconds. Default: 15s.", nil)];
    self.view_hierarchyTimeout.buttonX = controlX;
    self.view_hierarchyTimeout.didChange = ^(double doubleValue) {
        [LKPreferenceManager mainManager].hierarchyRequestTimeoutInterval = doubleValue;
    };
    [self.view addSubview:self.view_hierarchyTimeout];

#if DEBUG
    self.view_licenseTimeout = [[LKPreferenceNumberInputView alloc] initWithTitle:NSLocalizedString(@"License Timeout", nil) message:NSLocalizedString(@"Timeout for license challenge and verification requests, in seconds. Default: 5s.", nil)];
    self.view_licenseTimeout.buttonX = controlX;
    self.view_licenseTimeout.didChange = ^(double doubleValue) {
        [LKPreferenceManager mainManager].licenseHandshakeTimeoutInterval = doubleValue;
    };
    [self.view addSubview:self.view_licenseTimeout];
#endif
    
//    self.debugButton = [NSButton lk_normalButtonWithTitle:@"Debug" target:self action:@selector(_handleDebugButton)];
//    [self.view addSubview:self.debugButton];
    
    self.resetButton = [NSButton lk_normalButtonWithTitle:NSLocalizedString(@"Reset", nil) target:self action:@selector(_handleResetButton)];
    [self.view addSubview:self.resetButton];
    
    [self renderFromPreferenceManager];
}

- (void)renderFromPreferenceManager {
    LKPreferenceManager *manager = [LKPreferenceManager mainManager];
    
    if (manager.rgbaFormat) {
        self.view_colorFormat.selectedIndex = 0;
    } else {
        self.view_colorFormat.selectedIndex = 1;
    }

    self.view_contrast.selectedIndex = manager.imageContrastLevel;

    self.view_appearance.selectedIndex = manager.appearanceType;
    self.view_doubleClick.selectedIndex = manager.doubleClickBehavior;
    self.view_hierarchyTimeout.doubleValue = manager.hierarchyRequestTimeoutInterval;
#if DEBUG
    self.view_licenseTimeout.doubleValue = manager.licenseHandshakeTimeoutInterval;
#endif
}

- (void)viewDidLayout {
    [super viewDidLayout];
    
    NSEdgeInsets insets = NSEdgeInsetsMake(20, 30, 10, 30);
    
    $(self.view_appearance).x(insets.left).toRight(insets.right).y(insets.top).height(50);

    $(self.view_colorFormat).x(insets.left).toRight(insets.right).y(self.view_appearance.$maxY).height(80);
    $(self.view_contrast).x(insets.left).toRight(insets.right).y(self.view_colorFormat.$maxY).height(65);
    
    $(self.view_doubleClick).x(insets.left).toRight(insets.right).y(self.view_contrast.$maxY).height(50);
    $(self.view_hierarchyTimeout).x(insets.left).toRight(insets.right).y(self.view_doubleClick.$maxY).height(65);
#if DEBUG
    $(self.view_licenseTimeout).x(insets.left).toRight(insets.right).y(self.view_hierarchyTimeout.$maxY).height(65);
#endif
    
    $(self.resetButton).width(120).bottom(insets.bottom).right(insets.right);
//    $(self.debugButton).bottom(insets.bottom).maxX(self.resetButton.$x - 15);
}

- (void)_handleResetButton {
    LKPreferenceManager *manager = [LKPreferenceManager mainManager];
    manager.appearanceType = LookinPreferredAppeanranceTypeSystem;
    manager.rgbaFormat = YES;
    manager.doubleClickBehavior = LookinDoubleClickBehaviorCollapse;
    manager.imageContrastLevel = 0;
    manager.hierarchyRequestTimeoutInterval = LKDefaultHierarchyRequestTimeoutInterval;
    manager.licenseHandshakeTimeoutInterval = LKDefaultLicenseHandshakeTimeoutInterval;
    [self renderFromPreferenceManager];
    
#if DEBUG
    [[LKMessageManager sharedInstance] reset];
    [[LKPreferenceManager mainManager] reset];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"IgnoreFastModeTips"];
#endif
}

- (void)_handleDebugButton {
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
