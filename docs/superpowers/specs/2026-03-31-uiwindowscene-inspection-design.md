# UIWindowScene Attribute Inspection Support

## Overview

Add UIWindowScene as a first-class inspectable object in Lookin's hierarchy tree on iOS. Scene nodes appear as container parents of UIWindow nodes, replicating the NSWindow top-level pattern used on macOS.

## Motivation

- iOS 13+ uses UIWindowScene to manage windows; inspecting scene-level state (activation, orientation, traits, status bar) is essential for debugging multi-window iPad / Mac Catalyst / visionOS apps.
- The NSWindow inspection implementation (recent commits) provides an exact template to follow.

## Design Decisions

| Decision              | Choice                                                    | Rationale                                                                                                                    |
| --------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Hierarchy model       | Scene as container node                                   | Matches NSWindow top-level pattern; intuitive for multi-scene                                                                |
| Display item property | Reuse `windowObject`                                      | UIWindowScene is not a UIView subclass (same as NSWindow); avoids model changes; `displayingObject` priority already correct |
| Scene subclass scope  | UIWindowScene only                                        | Only UIWindowScene holds UIWindow/view hierarchy; filter with `isKindOfClass:`                                               |
| Minimum iOS version   | iOS 13                                                    | UIWindowScene introduced in iOS 13                                                                                           |
| Implementation phases | Phase 1 (core ~15 attrs) then Phase 2 (platform-specific) | Validate architecture before expanding                                                                                       |

## Hierarchy Structure

```
UIWindowScene  (windowObject, via connectedScenes)
  ├── UIWindow (viewObject + layerObject, key window)
  │     └── UIView
  │           └── ...
  └── UIWindow (viewObject + layerObject)
        └── UIView
              └── ...
```

On iOS, `LKS_HierarchyDisplayItemsMaker` changes from flat window iteration to:

1. Iterate `UIApplication.sharedApplication.connectedScenes`
2. Filter for `UIWindowScene` instances
3. For each scene: create a `LookinDisplayItem` with `windowObject = scene`
4. Scene's `subitems` = display items for each window in the scene (existing UIWindow → layer path)

## Phase 1 — Core Attributes (~15 properties)

### Attribute Sections

| Section         | Attr ID suffix       | Property                              | Type                          | R/W | Min iOS |
| --------------- | -------------------- | ------------------------------------- | ----------------------------- | --- | ------- |
| **State**       | ActivationState      | `activationState`                     | enum (UISceneActivationState) | RO  | 13      |
| **Title**       | Title                | `title`                               | NSString                      | RW  | 13      |
| **Orientation** | InterfaceOrientation | `interfaceOrientation`                | enum (UIInterfaceOrientation) | RO  | 13      |
| **Windows**     | WindowCount          | `windows.count`                       | int                           | RO  | 13      |
| **Windows**     | KeyWindowClassName   | keyWindow class name                  | NSString                      | RO  | 13      |
| **Screen**      | ScreenBounds         | `screen.bounds`                       | CGRect                        | RO  | 13      |
| **Screen**      | ScreenScale          | `screen.scale`                        | float                         | RO  | 13      |
| **StatusBar**   | StatusBarHidden      | `statusBarManager.isStatusBarHidden`  | BOOL                          | RO  | 13      |
| **StatusBar**   | StatusBarStyle       | `statusBarManager.statusBarStyle`     | enum (UIStatusBarStyle)       | RO  | 13      |
| **StatusBar**   | StatusBarFrame       | `statusBarManager.statusBarFrame`     | CGRect                        | RO  | 13      |
| **Traits**      | UserInterfaceStyle   | `traitCollection.userInterfaceStyle`  | enum                          | RO  | 13      |
| **Traits**      | HorizontalSizeClass  | `traitCollection.horizontalSizeClass` | enum                          | RO  | 13      |
| **Traits**      | VerticalSizeClass    | `traitCollection.verticalSizeClass`   | enum                          | RO  | 13      |
| **Session**     | PersistentIdentifier | `session.persistentIdentifier`        | NSString                      | RO  | 13      |
| **Session**     | SessionRole          | `session.role`                        | NSString                      | RO  | 13      |

### Identifier Naming Convention

Following the three-level pattern:

- Group: `LookinAttrGroup_UIWindowScene` → string `@"UIWindowScene"`
- Section: `LookinAttrSec_UIWindowScene_State` → string `@"UIWindowScene_State"`
- Attr: `LookinAttr_UIWindowScene_State_ActivationState` → string `@"UIWindowScene_State_ActivationState"`

### Enum Lists (LKEnumListRegistry)

| Enum Name                  | Values                                                                              |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `UISceneActivationState`   | Unattached(-1), ForegroundActive(0), ForegroundInactive(1), Background(2)           |
| `UIInterfaceOrientation`   | Unknown(0), Portrait(1), PortraitUpsideDown(2), LandscapeLeft(3), LandscapeRight(4) |
| `UIStatusBarStyle`         | Default(0), LightContent(1), DarkContent(3)                                         |
| `UIUserInterfaceStyle`     | Unspecified(0), Light(1), Dark(2)                                                   |
| `UIUserInterfaceSizeClass` | Unspecified(0), Compact(1), Regular(2)                                              |

## Phase 2 — Platform-Specific Attributes (future)

To be added after Phase 1 is validated:

| Property                                                              | Min iOS                   | Platform     |
| --------------------------------------------------------------------- | ------------------------- | ------------ |
| `subtitle`                                                            | 15                        | All          |
| `keyWindow` (direct API)                                              | 15                        | All          |
| `isFullScreen`                                                        | 16                        | iPad/Mac     |
| `sizeRestrictions.minimumSize` / `.maximumSize` / `.allowsFullScreen` | 13 (nil on non-resizable) | iPad/Mac     |
| `windowingBehaviors.isClosable` / `.isMiniaturizable`                 | 16                        | Mac Catalyst |
| `effectiveGeometry.systemFrame`                                       | 16                        | iPad/Mac     |

## Files to Modify/Create

### New Files

1. `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.h` — category header
2. `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.m` — `lks_*` pass-through getters for sub-object properties (statusBarManager, screen, traitCollection, session)

### Modified Files (Server/Core — dual copies)

3. `Sources/LookinCore/LookinAttrIdentifiers.h` — add UIWindowScene group/section/attr externs
4. `Sources/LookinCore/LookinAttrIdentifiers.m` — add string value definitions
5. `Sources/LookinServer/Shared/LookinAttrIdentifiers.h` — sync copy
6. `Sources/LookinServer/Shared/LookinAttrIdentifiers.m` — sync copy
7. `Sources/LookinCore/LookinDashboardBlueprint.m` — register group/sections/attrs/metadata under `#if TARGET_OS_IPHONE`
8. `Sources/LookinServer/Shared/LookinDashboardBlueprint.m` — sync copy

### Modified Files (Server logic)

9. `Sources/LookinServer/Server/Others/LKS_AttrGroupsMaker.m` — new `+attrGroupsForWindowScene:` method
10. `Sources/LookinServer/Server/Others/LKS_HierarchyDisplayItemsMaker.m` — iOS path: iterate scenes, create scene display items, windows as subitems

### Modified Files (macOS client)

11. `LookInside/Dashboard/LKEnumListRegistry.m` — add 5 enum tables
12. `LookInside/Hierarchy/LKHierarchyRowView.m` — add `@"UIWindowScene"` to icon mapping dict

### No Changes Needed

- `LookinDisplayItem.h/.m` — reuse `windowObject`, no new properties
- `LookinDashboardBlueprint.m` guards — `isWindowPropertyWithAttrID:` and `isUIViewPropertyWithAttrID:` already handle `@"UIWindowScene"`

## Key Implementation Notes

- All UIWindowScene code guarded by `#if TARGET_OS_IPHONE`
- Category getters must nil-check `statusBarManager`, `sizeRestrictions` before accessing sub-properties
- `attrGroupsForWindowScene:` follows `attrGroupsForWindow:` pattern: manual Class/Relation/Layout groups first, then blueprint loop filtered by `isWindowPropertyWithAttrID:`
- For `lks_relatedClassChainList`: walk UIWindowScene class chain, truncate at UIScene
- For `lks_selfRelation`: show delegate class name if set
- Attr string values must be globally unique (persisted in UserDefaults)
- `interfaceOrientation` is deprecated but available on all iOS 13+; still useful for debugging
