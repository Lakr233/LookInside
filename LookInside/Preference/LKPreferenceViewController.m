//
//  LKPreferenceViewController.m
//  Lookin
//
//  Created by Li Kai on 2019/1/4.
//  https://lookin.work
//

#import "LKPreferenceViewController.h"
#import "LookInside-Swift.h"

@interface LKPreferenceViewController ()

@property(nonatomic, strong) NSViewController *hostingController;

@end

@implementation LKPreferenceViewController

- (void)setView:(NSView *)view {
    [super setView:view];
    [self _installSwiftUIPreferencesIfNeeded];
}

- (void)_installSwiftUIPreferencesIfNeeded {
    if (self.hostingController || !self.view) {
        return;
    }

    LKPreferenceHostingController *hostingController = [LKPreferenceHostingController new];
    self.hostingController = hostingController;

    [self addChildViewController:hostingController];
    hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:hostingController.view];

    [NSLayoutConstraint activateConstraints:@[
        [hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

@end
