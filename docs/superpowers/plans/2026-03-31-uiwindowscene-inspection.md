# UIWindowScene Inspection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add UIWindowScene as a first-class inspectable container node in Lookin's iOS hierarchy tree, with 15 core attribute properties.

**Architecture:** UIWindowScene nodes use `windowObject` on `LookinDisplayItem` (same as NSWindow on macOS). The iOS hierarchy path changes from flat window iteration to scene-grouped: each UIWindowScene becomes a container with its UIWindows as children. A new `UIWindowScene+LookinServer` category provides pass-through getters for sub-object properties. Identifiers, blueprint entries, and enum lists follow the exact NSWindow pattern.

**Tech Stack:** Objective-C, UIKit (iOS 13+), Lookin attribute inspection system

---

### Task 1: Create UIWindowScene+LookinServer Category

**Files:**

- Create: `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.h`
- Create: `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.m`

SPM auto-discovers files in `Sources/LookinServer/` — no Package.swift or pbxproj edits needed.

- [ ] **Step 1: Create the header file**

Create `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.h`:

```objc
#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && TARGET_OS_IPHONE
//
//  UIWindowScene+LookinServer.h
//  LookinServer
//

#import "TargetConditionals.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))
@interface UIWindowScene (LookinServer)

// Returns the class chain list for this scene, truncated at UIScene
- (NSArray<NSArray<NSString *> *> *)lks_relatedClassChainList;

// Returns the self relation strings (delegate class name)
- (NSArray<NSString *> *)lks_selfRelation;

// Pass-through getters for sub-object properties
@property (nonatomic, readonly) NSInteger lks_windowCount;
@property (nonatomic, readonly, nullable) NSString *lks_keyWindowClassName;
@property (nonatomic, readonly) CGRect lks_screenBounds;
@property (nonatomic, readonly) CGFloat lks_screenScale;
@property (nonatomic, readonly) BOOL lks_statusBarHidden;
@property (nonatomic, readonly) NSInteger lks_statusBarStyle;
@property (nonatomic, readonly) CGRect lks_statusBarFrame;
@property (nonatomic, readonly) NSInteger lks_userInterfaceStyle;
@property (nonatomic, readonly) NSInteger lks_horizontalSizeClass;
@property (nonatomic, readonly) NSInteger lks_verticalSizeClass;
@property (nonatomic, readonly, nullable) NSString *lks_sessionPersistentIdentifier;
@property (nonatomic, readonly, nullable) NSString *lks_sessionRole;

@end

NS_ASSUME_NONNULL_END

#endif
```

- [ ] **Step 2: Create the implementation file**

Create `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.m`:

```objc
#if defined(SHOULD_COMPILE_LOOKIN_SERVER) && TARGET_OS_IPHONE
//
//  UIWindowScene+LookinServer.m
//  LookinServer
//

#import "UIWindowScene+LookinServer.h"
#import "NSObject+LookinServer.h"
#import "NSArray+Lookin.h"

@implementation UIWindowScene (LookinServer)

- (NSArray<NSArray<NSString *> *> *)lks_relatedClassChainList {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
    NSArray<NSString *> *completedList = [self lks_classChainList];
    NSUInteger endingIndex = [completedList indexOfObject:@"UIScene"];
    if (endingIndex != NSNotFound) {
        completedList = [completedList subarrayWithRange:NSMakeRange(0, endingIndex + 1)];
    }
    [array addObject:completedList];
    return array.copy;
}

- (NSArray<NSString *> *)lks_selfRelation {
    NSMutableArray *array = [NSMutableArray array];
    if (self.delegate) {
        [array addObject:[NSString stringWithFormat:@"(%@ *) delegate", NSStringFromClass([(NSObject *)self.delegate class])]];
    }
    return array.copy;
}

- (NSInteger)lks_windowCount {
    return (NSInteger)self.windows.count;
}

- (NSString *)lks_keyWindowClassName {
    // keyWindow is available on UIWindowScene from iOS 15; use KVC fallback for iOS 13-14
    UIWindow *keyWindow = nil;
    if (@available(iOS 15.0, *)) {
        keyWindow = self.keyWindow;
    } else {
        for (UIWindow *window in self.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }
    return keyWindow ? NSStringFromClass(keyWindow.class) : nil;
}

- (CGRect)lks_screenBounds {
    return self.screen ? self.screen.bounds : CGRectZero;
}

- (CGFloat)lks_screenScale {
    return self.screen ? self.screen.scale : 1.0;
}

- (BOOL)lks_statusBarHidden {
    return self.statusBarManager ? self.statusBarManager.isStatusBarHidden : YES;
}

- (NSInteger)lks_statusBarStyle {
    return self.statusBarManager ? (NSInteger)self.statusBarManager.statusBarStyle : 0;
}

- (CGRect)lks_statusBarFrame {
    return self.statusBarManager ? self.statusBarManager.statusBarFrame : CGRectZero;
}

- (NSInteger)lks_userInterfaceStyle {
    return (NSInteger)self.traitCollection.userInterfaceStyle;
}

- (NSInteger)lks_horizontalSizeClass {
    return (NSInteger)self.traitCollection.horizontalSizeClass;
}

- (NSInteger)lks_verticalSizeClass {
    return (NSInteger)self.traitCollection.verticalSizeClass;
}

- (NSString *)lks_sessionPersistentIdentifier {
    return self.session.persistentIdentifier;
}

- (NSString *)lks_sessionRole {
    return self.session.role;
}

@end

#endif
```

- [ ] **Step 3: Build to verify compilation**

Run: `swift build 2>&1 | head -20`
Expected: BUILD SUCCEEDED (or at minimum, no errors in the new files)

- [ ] **Step 4: Commit**

```bash
git add Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.h Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.m
git commit -m "feat: add UIWindowScene+LookinServer category with pass-through getters"
```

---

### Task 2: Add UIWindowScene Attribute Identifiers (LookinCore copy)

**Files:**

- Modify: `Sources/LookinCore/LookinAttrIdentifiers.h` (add after NSWindow identifiers)
- Modify: `Sources/LookinCore/LookinAttrIdentifiers.m` (add after NSWindow definitions)

- [ ] **Step 1: Add group, section, and attr extern declarations to .h**

In `Sources/LookinCore/LookinAttrIdentifiers.h`, add after the NSWindow attr block (after line 633, before `LookinAttr_NSSlider_SliderType_SliderType`):

```objc
// UIWindowScene
extern LookinAttrGroupIdentifier const LookinAttrGroup_UIWindowScene;

extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_State;
extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Title;
extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Orientation;
extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Windows;
extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Screen;
extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_StatusBar;
extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Traits;
extern LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Session;

extern LookinAttrIdentifier const LookinAttr_UIWindowScene_State_ActivationState;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Title_Title;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Orientation_InterfaceOrientation;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Windows_WindowCount;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Windows_KeyWindowClassName;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Screen_ScreenBounds;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Screen_ScreenScale;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_StatusBar_StatusBarHidden;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_StatusBar_StatusBarStyle;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_StatusBar_StatusBarFrame;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Traits_UserInterfaceStyle;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Traits_HorizontalSizeClass;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Traits_VerticalSizeClass;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Session_PersistentIdentifier;
extern LookinAttrIdentifier const LookinAttr_UIWindowScene_Session_SessionRole;
```

- [ ] **Step 2: Add string value definitions to .m**

In `Sources/LookinCore/LookinAttrIdentifiers.m`, add after the NSWindow attr definitions block (after line 617, before `LookinAttr_NSSlider_SliderType_SliderType`):

```objc
// UIWindowScene
LookinAttrGroupIdentifier const LookinAttrGroup_UIWindowScene = @"UIWindowScene";

LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_State = @"UIWindowScene_State";
LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Title = @"UIWindowScene_Title";
LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Orientation = @"UIWindowScene_Orientation";
LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Windows = @"UIWindowScene_Windows";
LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Screen = @"UIWindowScene_Screen";
LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_StatusBar = @"UIWindowScene_StatusBar";
LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Traits = @"UIWindowScene_Traits";
LookinAttrSectionIdentifier const LookinAttrSec_UIWindowScene_Session = @"UIWindowScene_Session";

LookinAttrIdentifier const LookinAttr_UIWindowScene_State_ActivationState = @"UIWindowScene_State_ActivationState";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Title_Title = @"UIWindowScene_Title_Title";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Orientation_InterfaceOrientation = @"UIWindowScene_Orientation_InterfaceOrientation";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Windows_WindowCount = @"UIWindowScene_Windows_WindowCount";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Windows_KeyWindowClassName = @"UIWindowScene_Windows_KeyWindowClassName";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Screen_ScreenBounds = @"UIWindowScene_Screen_ScreenBounds";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Screen_ScreenScale = @"UIWindowScene_Screen_ScreenScale";
LookinAttrIdentifier const LookinAttr_UIWindowScene_StatusBar_StatusBarHidden = @"UIWindowScene_StatusBar_StatusBarHidden";
LookinAttrIdentifier const LookinAttr_UIWindowScene_StatusBar_StatusBarStyle = @"UIWindowScene_StatusBar_StatusBarStyle";
LookinAttrIdentifier const LookinAttr_UIWindowScene_StatusBar_StatusBarFrame = @"UIWindowScene_StatusBar_StatusBarFrame";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Traits_UserInterfaceStyle = @"UIWindowScene_Traits_UserInterfaceStyle";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Traits_HorizontalSizeClass = @"UIWindowScene_Traits_HorizontalSizeClass";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Traits_VerticalSizeClass = @"UIWindowScene_Traits_VerticalSizeClass";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Session_PersistentIdentifier = @"UIWindowScene_Session_PersistentIdentifier";
LookinAttrIdentifier const LookinAttr_UIWindowScene_Session_SessionRole = @"UIWindowScene_Session_SessionRole";
```

- [ ] **Step 3: Commit**

```bash
git add Sources/LookinCore/LookinAttrIdentifiers.h Sources/LookinCore/LookinAttrIdentifiers.m
git commit -m "feat: add UIWindowScene attribute identifiers to LookinCore"
```

---

### Task 3: Add UIWindowScene Attribute Identifiers (LookinServer/Shared copy)

**Files:**

- Modify: `Sources/LookinServer/Shared/LookinAttrIdentifiers.h` (NSWindow group at line 46, sections at lines 244–259, attrs at lines 512–556)
- Modify: `Sources/LookinServer/Shared/LookinAttrIdentifiers.m` (NSWindow group at line 48, sections at lines 234–248, attrs at lines 496–540)

- [ ] **Step 1: Add declarations to Shared .h**

In `Sources/LookinServer/Shared/LookinAttrIdentifiers.h`, add after the last NSWindow attr declaration (after line 556, the `LookinAttr_NSWindow_Info_BackingScaleFactor` line). Add the **exact same block** as Task 2 Step 1 (the extern declarations for UIWindowScene group, 8 sections, and 15 attrs).

- [ ] **Step 2: Add definitions to Shared .m**

In `Sources/LookinServer/Shared/LookinAttrIdentifiers.m`, add after the last NSWindow attr definition (after line 540, the `LookinAttr_NSWindow_Info_BackingScaleFactor` line). Add the **exact same block** as Task 2 Step 2 (the string value definitions).

- [ ] **Step 3: Commit**

```bash
git add Sources/LookinServer/Shared/LookinAttrIdentifiers.h Sources/LookinServer/Shared/LookinAttrIdentifiers.m
git commit -m "feat: add UIWindowScene attribute identifiers to LookinServer/Shared"
```

---

### Task 4: Register UIWindowScene in LookinDashboardBlueprint (LookinCore copy)

**Files:**

- Modify: `Sources/LookinCore/LookinDashboardBlueprint.m`

Four locations to edit within this file.

- [ ] **Step 1: Add group to `+groupIDs`**

At line 37 (after `LookinAttrGroup_UITextField`), before the `#endif` on line 38, add:

```objc
            LookinAttrGroup_UIWindowScene,
```

The result should be:

```objc
            LookinAttrGroup_UITextField,
            LookinAttrGroup_UIWindowScene
#endif
```

Note: remove trailing comma from `LookinAttrGroup_UITextField` is NOT needed — ObjC array literals allow trailing commas.

- [ ] **Step 2: Add section mapping to `+sectionIDsForGroupID:`**

Find the `#if TARGET_OS_IPHONE` section block in `sectionIDsForGroupID:`. After the last iOS entry (the `LookinAttrGroup_UITextField` mapping), add before the `#endif`:

```objc
            LookinAttrGroup_UIWindowScene: @[
                LookinAttrSec_UIWindowScene_State,
                LookinAttrSec_UIWindowScene_Title,
                LookinAttrSec_UIWindowScene_Orientation,
                LookinAttrSec_UIWindowScene_Windows,
                LookinAttrSec_UIWindowScene_Screen,
                LookinAttrSec_UIWindowScene_StatusBar,
                LookinAttrSec_UIWindowScene_Traits,
                LookinAttrSec_UIWindowScene_Session,
            ],
```

- [ ] **Step 3: Add attr ID mappings to `+attrIDsForSectionID:`**

Find the `#if TARGET_OS_IPHONE` section block in `attrIDsForSectionID:`. After the last iOS entry, add before the `#endif`:

```objc
            LookinAttrSec_UIWindowScene_State: @[
                LookinAttr_UIWindowScene_State_ActivationState,
            ],
            LookinAttrSec_UIWindowScene_Title: @[
                LookinAttr_UIWindowScene_Title_Title,
            ],
            LookinAttrSec_UIWindowScene_Orientation: @[
                LookinAttr_UIWindowScene_Orientation_InterfaceOrientation,
            ],
            LookinAttrSec_UIWindowScene_Windows: @[
                LookinAttr_UIWindowScene_Windows_WindowCount,
                LookinAttr_UIWindowScene_Windows_KeyWindowClassName,
            ],
            LookinAttrSec_UIWindowScene_Screen: @[
                LookinAttr_UIWindowScene_Screen_ScreenBounds,
                LookinAttr_UIWindowScene_Screen_ScreenScale,
            ],
            LookinAttrSec_UIWindowScene_StatusBar: @[
                LookinAttr_UIWindowScene_StatusBar_StatusBarHidden,
                LookinAttr_UIWindowScene_StatusBar_StatusBarStyle,
                LookinAttr_UIWindowScene_StatusBar_StatusBarFrame,
            ],
            LookinAttrSec_UIWindowScene_Traits: @[
                LookinAttr_UIWindowScene_Traits_UserInterfaceStyle,
                LookinAttr_UIWindowScene_Traits_HorizontalSizeClass,
                LookinAttr_UIWindowScene_Traits_VerticalSizeClass,
            ],
            LookinAttrSec_UIWindowScene_Session: @[
                LookinAttr_UIWindowScene_Session_PersistentIdentifier,
                LookinAttr_UIWindowScene_Session_SessionRole,
            ],
```

- [ ] **Step 4: Add per-attr metadata to `_infoForAttrID:`**

After the last NSWindow entry (line ~3143), add before `// MARK: - NSSlider`:

```objc
            // MARK: - UIWindowScene
            LookinAttr_UIWindowScene_State_ActivationState: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"ActivationState",
                @"getterString": @"activationState",
                @"setterString": @"",
                @"enumList": @"UISceneActivationState",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Title_Title: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"Title",
                @"patch": @(YES),
                @"typeIfObj": @(LookinAttrTypeNSString)
            },
            LookinAttr_UIWindowScene_Orientation_InterfaceOrientation: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"InterfaceOrientation",
                @"setterString": @"",
                @"enumList": @"UIInterfaceOrientation",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Windows_WindowCount: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"WindowCount",
                @"getterString": @"lks_windowCount",
                @"setterString": @"",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Windows_KeyWindowClassName: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"KeyWindowClassName",
                @"getterString": @"lks_keyWindowClassName",
                @"setterString": @"",
                @"typeIfObj": @(LookinAttrTypeNSString),
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Screen_ScreenBounds: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"ScreenBounds",
                @"getterString": @"lks_screenBounds",
                @"setterString": @"",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Screen_ScreenScale: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"ScreenScale",
                @"getterString": @"lks_screenScale",
                @"setterString": @"",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_StatusBar_StatusBarHidden: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"StatusBarHidden",
                @"getterString": @"lks_statusBarHidden",
                @"setterString": @"",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_StatusBar_StatusBarStyle: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"StatusBarStyle",
                @"getterString": @"lks_statusBarStyle",
                @"setterString": @"",
                @"enumList": @"UIStatusBarStyle",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_StatusBar_StatusBarFrame: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"StatusBarFrame",
                @"getterString": @"lks_statusBarFrame",
                @"setterString": @"",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Traits_UserInterfaceStyle: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"UserInterfaceStyle",
                @"getterString": @"lks_userInterfaceStyle",
                @"setterString": @"",
                @"enumList": @"UIUserInterfaceStyle",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Traits_HorizontalSizeClass: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"HorizontalSizeClass",
                @"getterString": @"lks_horizontalSizeClass",
                @"setterString": @"",
                @"enumList": @"UIUserInterfaceSizeClass",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Traits_VerticalSizeClass: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"VerticalSizeClass",
                @"getterString": @"lks_verticalSizeClass",
                @"setterString": @"",
                @"enumList": @"UIUserInterfaceSizeClass",
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Session_PersistentIdentifier: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"PersistentIdentifier",
                @"getterString": @"lks_sessionPersistentIdentifier",
                @"setterString": @"",
                @"typeIfObj": @(LookinAttrTypeNSString),
                @"patch": @(NO)
            },
            LookinAttr_UIWindowScene_Session_SessionRole: @{
                @"className": @"UIWindowScene",
                @"fullTitle": @"SessionRole",
                @"getterString": @"lks_sessionRole",
                @"setterString": @"",
                @"typeIfObj": @(LookinAttrTypeNSString),
                @"patch": @(NO)
            },
```

- [ ] **Step 5: Commit**

```bash
git add Sources/LookinCore/LookinDashboardBlueprint.m
git commit -m "feat: register UIWindowScene blueprint entries in LookinCore"
```

---

### Task 5: Register UIWindowScene in LookinDashboardBlueprint (LookinServer/Shared copy)

**Files:**

- Modify: `Sources/LookinServer/Shared/LookinDashboardBlueprint.m`

Apply the **exact same four changes** as Task 4, but at the Shared copy's line numbers:

- [ ] **Step 1: Add `LookinAttrGroup_UIWindowScene` to `+groupIDs`**

Add after `LookinAttrGroup_UITextField` (line 37) in the `#if TARGET_OS_IPHONE` block, same as Task 4 Step 1.

- [ ] **Step 2: Add section mapping to `+sectionIDsForGroupID:`**

Add the UIWindowScene section mapping after the last iOS entry, same content as Task 4 Step 2.

- [ ] **Step 3: Add attr ID mappings to `+attrIDsForSectionID:`**

Add the UIWindowScene attr mappings after the last iOS entry, same content as Task 4 Step 3.

- [ ] **Step 4: Add per-attr metadata to `_infoForAttrID:`**

Add after the last NSWindow entry (line ~2771 in the Shared copy), same content as Task 4 Step 4.

- [ ] **Step 5: Commit**

```bash
git add Sources/LookinServer/Shared/LookinDashboardBlueprint.m
git commit -m "feat: register UIWindowScene blueprint entries in LookinServer/Shared"
```

---

### Task 6: Add `attrGroupsForWindowScene:` to LKS_AttrGroupsMaker

**Files:**

- Modify: `Sources/LookinServer/Server/Others/LKS_AttrGroupsMaker.m`

- [ ] **Step 1: Add import for UIWindowScene+LookinServer.h**

At the top of the file, after line 13 (`#endif` for the `TARGET_OS_OSX` / NSWindow import), add:

```objc
#if TARGET_OS_IPHONE
#import "UIWindowScene+LookinServer.h"
#endif
```

- [ ] **Step 2: Add the `+attrGroupsForWindowScene:` method**

After the `#endif` closing `attrGroupsForWindow:` (line 280), add:

```objc
#if TARGET_OS_IPHONE
+ (NSArray<LookinAttributesGroup *> *)attrGroupsForWindowScene:(UIWindowScene *)windowScene API_AVAILABLE(ios(13.0)) {
    if (!windowScene) {
        NSAssert(NO, @"");
        return nil;
    }

    NSMutableArray<LookinAttributesGroup *> *result = [NSMutableArray array];

    // Class group - show scene class hierarchy
    {
        LookinAttribute *classAttr = [LookinAttribute new];
        classAttr.identifier = LookinAttr_Class_Class_Class;
        classAttr.attrType = LookinAttrTypeCustomObj;
        classAttr.value = [windowScene lks_relatedClassChainList];

        LookinAttributesSection *classSec = [LookinAttributesSection new];
        classSec.identifier = LookinAttrSec_Class_Class;
        classSec.attributes = @[classAttr];

        LookinAttributesGroup *classGroup = [LookinAttributesGroup new];
        classGroup.identifier = LookinAttrGroup_Class;
        classGroup.attrSections = @[classSec];
        [result addObject:classGroup];
    }

    // Relation group - show delegate relation
    {
        NSArray<NSString *> *selfRelation = [windowScene lks_selfRelation];
        if (selfRelation.count > 0) {
            LookinAttribute *relationAttr = [LookinAttribute new];
            relationAttr.identifier = LookinAttr_Relation_Relation_Relation;
            relationAttr.attrType = LookinAttrTypeCustomObj;
            relationAttr.value = selfRelation;

            LookinAttributesSection *relationSec = [LookinAttributesSection new];
            relationSec.identifier = LookinAttrSec_Relation_Relation;
            relationSec.attributes = @[relationAttr];

            LookinAttributesGroup *relationGroup = [LookinAttributesGroup new];
            relationGroup.identifier = LookinAttrGroup_Relation;
            relationGroup.attrSections = @[relationSec];
            [result addObject:relationGroup];
        }
    }

    // UIWindowScene-specific groups from blueprint
    NSArray<LookinAttributesGroup *> *blueprintGroups = [[LookinDashboardBlueprint groupIDs] lookin_map:^id(NSUInteger idx, LookinAttrGroupIdentifier groupID) {
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

                if (![LookinDashboardBlueprint isWindowPropertyWithAttrID:attrID]) {
                    return nil;
                }

                Class targetClass = NSClassFromString([LookinDashboardBlueprint classNameWithAttrID:attrID]);
                if (![windowScene isKindOfClass:targetClass]) {
                    return nil;
                }

                LookinAttribute *attr = [self _attributeWithIdentifer:attrID targetObject:windowScene];
                return attr;
            }];

            if (sec.attributes.count) {
                return sec;
            } else {
                return nil;
            }
        }];

        if (group.attrSections.count) {
            return group;
        } else {
            return nil;
        }
    }];

    [result addObjectsFromArray:blueprintGroups];
    return result;
}
#endif
```

- [ ] **Step 3: Declare the new method in the header**

In `Sources/LookinServer/Server/Others/LKS_AttrGroupsMaker.h`, find the existing method declarations and add:

```objc
#if TARGET_OS_IPHONE
+ (NSArray<LookinAttributesGroup *> *)attrGroupsForWindowScene:(UIWindowScene *)windowScene API_AVAILABLE(ios(13.0));
#endif
```

- [ ] **Step 4: Build to verify**

Run: `swift build 2>&1 | head -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Sources/LookinServer/Server/Others/LKS_AttrGroupsMaker.h Sources/LookinServer/Server/Others/LKS_AttrGroupsMaker.m
git commit -m "feat: add attrGroupsForWindowScene method to LKS_AttrGroupsMaker"
```

---

### Task 7: Modify LKS_HierarchyDisplayItemsMaker for Scene Hierarchy

**Files:**

- Modify: `Sources/LookinServer/Server/Others/LKS_HierarchyDisplayItemsMaker.m`

This is the most critical change — the iOS path switches from flat window iteration to scene-grouped hierarchy.

- [ ] **Step 1: Add import**

After line 26 (`#import "NSWindow+LookinServer.h"`), add:

```objc
#if TARGET_OS_IPHONE
#import "UIWindowScene+LookinServer.h"
#endif
```

- [ ] **Step 2: Rewrite the iOS path in the main entry point**

Replace the `#if TARGET_OS_IPHONE` block inside the main method (lines 33–37 and the shared code at lines 66–70). The entire method body from line 29 needs to be restructured.

Replace the method body (lines 30–72) with:

```objc
    [[LKS_TraceManager sharedInstance] reload];

#if TARGET_OS_IPHONE
    // iOS: group windows by UIWindowScene, scene is the top-level container
    NSMutableArray<LookinDisplayItem *> *resultArray = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;

        // Create the scene display item
        LookinDisplayItem *sceneItem = [LookinDisplayItem new];
        sceneItem.windowObject = [LookinObject instanceWithObject:windowScene];
        sceneItem.shouldCaptureImage = NO;

        if (hasAttrList) {
            sceneItem.attributesGroupList = [LKS_AttrGroupsMaker attrGroupsForWindowScene:windowScene];
        }

        // Build child items for each window in this scene
        NSMutableArray<LookinDisplayItem *> *windowItems = [NSMutableArray array];
        NSArray<UIWindow *> *windows = windowScene.windows;
        for (UIWindow *window in windows) {
            LookinDisplayItem *windowItem = [self _displayItemWithLayer:window.layer screenshots:hasScreenshots attrList:hasAttrList lowImageQuality:lowQuality readCustomInfo:readCustomInfo saveCustomSetter:saveCustomSetter];
            windowItem.representedAsKeyWindow = window.isKeyWindow;
            if (windowItem) {
                [windowItems addObject:windowItem];
            }
        }

        // Also check for keyWindow not in windows list (e.g. form sheet presentations)
        UIWindow *keyWindow = nil;
        if (@available(iOS 15.0, *)) {
            keyWindow = windowScene.keyWindow;
        } else {
            for (UIWindow *window in windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
        }
        if (keyWindow && ![windows containsObject:keyWindow]) {
            if (![NSStringFromClass(keyWindow.class) containsString:@"HUD"]) {
                LookinDisplayItem *keyWindowItem = [self _displayItemWithLayer:keyWindow.layer screenshots:hasScreenshots attrList:hasAttrList lowImageQuality:lowQuality readCustomInfo:readCustomInfo saveCustomSetter:saveCustomSetter];
                keyWindowItem.representedAsKeyWindow = YES;
                if (keyWindowItem) {
                    [windowItems addObject:keyWindowItem];
                }
            }
        }

        sceneItem.subitems = windowItems;
        [resultArray addObject:sceneItem];
    }

    return [resultArray copy];
#elif TARGET_OS_OSX
    NSArray<LookinWindow *> *windows = [LKS_MultiplatformAdapter allWindows];
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:windows.count];
    [windows enumerateObjectsUsingBlock:^(__kindof LookinWindow * _Nonnull window, NSUInteger idx, BOOL * _Nonnull stop) {
        // macOS: view is the source of truth — always start from the root view
        NSView *rootView = window.lks_rootView;
        LookinDisplayItem *item = [LookinDisplayItem new];
        item.windowObject = [LookinObject instanceWithObject:window];
        item.frame = window.lks_bounds;
        item.bounds = window.lks_bounds;
        item.backgroundColor = window.backgroundColor;
        item.shouldCaptureImage = YES;
        item.alpha = window.alphaValue;
        if (rootView.layer) {
            item.groupScreenshot = [rootView.layer lks_groupScreenshotWithLowQuality:lowQuality];
            item.soloScreenshot = [rootView.layer lks_soloScreenshotWithLowQuality:lowQuality];
        } else {
            item.groupScreenshot = [rootView lks_groupScreenshotWithLowQuality:lowQuality];
            item.soloScreenshot = [rootView lks_soloScreenshotWithLowQuality:lowQuality];
        }
        item.screenshotEncodeType = LookinDisplayItemImageEncodeTypeNSData;
        if (window.windowController) {
            item.hostWindowControllerObject = [LookinObject instanceWithObject:window.windowController];
        }
        if (hasAttrList) {
            item.attributesGroupList = [LKS_AttrGroupsMaker attrGroupsForWindow:window];
        }
        if (rootView) {
            item.subitems = @[[self _displayItemWithView:rootView screenshots:hasScreenshots attrList:hasAttrList lowImageQuality:lowQuality readCustomInfo:readCustomInfo saveCustomSetter:saveCustomSetter]];
        }
        item.representedAsKeyWindow = window.isKeyWindow;
        if (item) {
            [resultArray addObject:item];
        }
    }];

    return [resultArray copy];
#endif
```

- [ ] **Step 3: Build to verify**

Run: `swift build 2>&1 | head -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/LookinServer/Server/Others/LKS_HierarchyDisplayItemsMaker.m
git commit -m "feat: restructure iOS hierarchy to use UIWindowScene as container node"
```

---

### Task 8: Add Enum Lists to LKEnumListRegistry

**Files:**

- Modify: `LookInside/Dashboard/LKEnumListRegistry.m`

- [ ] **Step 1: Add 5 UIWindowScene-related enum tables**

After the NSWindow enum entries (after line 423, before `// MARK: - NSSlider`), add:

```objc
    // MARK: - UIWindowScene
    mData[@"UISceneActivationState"] = @[
        MakeItem(@"UISceneActivationStateUnattached", -1),
        MakeItem(@"UISceneActivationStateForegroundActive", 0),
        MakeItem(@"UISceneActivationStateForegroundInactive", 1),
        MakeItem(@"UISceneActivationStateBackground", 2),
    ];
    mData[@"UIInterfaceOrientation"] = @[
        MakeItem(@"UIInterfaceOrientationUnknown", 0),
        MakeItem(@"UIInterfaceOrientationPortrait", 1),
        MakeItem(@"UIInterfaceOrientationPortraitUpsideDown", 2),
        MakeItem(@"UIInterfaceOrientationLandscapeLeft", 3),
        MakeItem(@"UIInterfaceOrientationLandscapeRight", 4),
    ];
    mData[@"UIStatusBarStyle"] = @[
        MakeItem(@"UIStatusBarStyleDefault", 0),
        MakeItem(@"UIStatusBarStyleLightContent", 1),
        MakeItem(@"UIStatusBarStyleDarkContent", 3),
    ];
    mData[@"UIUserInterfaceStyle"] = @[
        MakeItem(@"UIUserInterfaceStyleUnspecified", 0),
        MakeItem(@"UIUserInterfaceStyleLight", 1),
        MakeItem(@"UIUserInterfaceStyleDark", 2),
    ];
    mData[@"UIUserInterfaceSizeClass"] = @[
        MakeItem(@"UIUserInterfaceSizeClassUnspecified", 0),
        MakeItem(@"UIUserInterfaceSizeClassCompact", 1),
        MakeItem(@"UIUserInterfaceSizeClassRegular", 2),
    ];
```

- [ ] **Step 2: Commit**

```bash
git add LookInside/Dashboard/LKEnumListRegistry.m
git commit -m "feat: add UIWindowScene-related enum lists to LKEnumListRegistry"
```

---

### Task 9: Add UIWindowScene Icon Mapping to LKHierarchyRowView

**Files:**

- Modify: `LookInside/Hierarchy/LKHierarchyRowView.m`

- [ ] **Step 1: Add UIWindowScene to the class-to-icon mapping dictionary**

At line 303 (after the `@{@"UIWindow": @"hierarchy_window"},` entry), add:

```objc
                      @{@"UIWindowScene": @"hierarchy_window"},
```

- [ ] **Step 2: Commit**

```bash
git add LookInside/Hierarchy/LKHierarchyRowView.m
git commit -m "feat: add UIWindowScene icon mapping to hierarchy row view"
```

---

### Task 10: Sync DerivedSource and Build Verification

**Files:**

- Run: `Scripts/sync-derived-source.sh`

- [ ] **Step 1: Run sync script**

Run: `bash Scripts/sync-derived-source.sh`
Expected: No errors. This copies `Sources/LookinCore/` to `LookInside/DerivedSource/LookinCore/`.

- [ ] **Step 2: Build SPM package**

Run: `swift build 2>&1 | head -30`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Build Xcode project**

Run: `xcodebuild -project LookInside.xcodeproj -scheme LookInside -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit synced DerivedSource if changed**

```bash
git add LookInside/DerivedSource/
git commit -m "chore: sync DerivedSource after UIWindowScene changes"
```

- [ ] **Step 5: Verify final state**

Run: `git log --oneline -10`
Expected: All commits from Tasks 1-10 visible on `feat/uiwindowscene-support` branch.
