# UITraitCollection Full Inspection Support

## Overview

Add comprehensive UITraitCollection inspection at two levels:

1. **Per-UIView** — new `LookinAttrGroup_UITraitCollection` group showing all standard trait properties for any UIView
2. **UIWindowScene** — expand the existing `LookinAttrSec_UIWindowScene_Traits` section with additional trait properties and scene-specific traits

## Motivation

- iOS 17+ supports per-view trait overrides via `UITraitOverrides`; inspecting traits at the view level is essential for debugging trait propagation
- The existing scene-level traits only cover 3 of 15+ available properties
- Properties like `accessibilityContrast`, `preferredContentSizeCategory`, `displayGamut`, and `layoutDirection` are commonly needed for debugging adaptive UI

## Design Decisions

| Decision                 | Choice                         | Rationale                                                                                                                             |
| ------------------------ | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Architecture approach    | Two separate groups (B)        | UIWindowScene already has its own group; UIView traits get a new group; avoids overloading either; `isKindOfClass:` matches precisely |
| UIView trait className   | `UIView`                       | All UIView subclasses inherit `traitCollection`; walks existing `isUIViewPropertyWithAttrID:` path                                    |
| Scene-only traits        | `sceneCaptureState`            | Only meaningful at scene level; not added to per-view group                                                                           |
| `forceTouchCapability`   | View-level only                | Deprecated in iOS 17, nearly unused on scenes                                                                                         |
| Getter pattern           | `lks_traitCollection_*` prefix | Avoids name collisions with existing `lks_*` methods; clear that these read from `traitCollection`                                    |
| All properties read-only | `setterString = @""`           | Trait values are derived from the environment; direct mutation not supported                                                          |

## UIView Level — `LookinAttrGroup_UITraitCollection`

### Sections and Attributes

#### Appearance (`LookinAttrSec_UITraitCollection_Appearance`)

| Attr ID Suffix        | Property                                | Type | Enum                            | Min iOS |
| --------------------- | --------------------------------------- | ---- | ------------------------------- | ------- |
| UserInterfaceStyle    | `traitCollection.userInterfaceStyle`    | enum | UIUserInterfaceStyle            | 12      |
| UserInterfaceLevel    | `traitCollection.userInterfaceLevel`    | enum | UIUserInterfaceLevel            | 13      |
| ActiveAppearance      | `traitCollection.activeAppearance`      | enum | UIUserInterfaceActiveAppearance | 14      |
| AccessibilityContrast | `traitCollection.accessibilityContrast` | enum | UIAccessibilityContrast         | 13      |
| LegibilityWeight      | `traitCollection.legibilityWeight`      | enum | UILegibilityWeight              | 13      |

#### Size Class (`LookinAttrSec_UITraitCollection_SizeClass`)

| Attr ID Suffix      | Property                              | Type | Enum                     | Min iOS |
| ------------------- | ------------------------------------- | ---- | ------------------------ | ------- |
| HorizontalSizeClass | `traitCollection.horizontalSizeClass` | enum | UIUserInterfaceSizeClass | 8       |
| VerticalSizeClass   | `traitCollection.verticalSizeClass`   | enum | UIUserInterfaceSizeClass | 8       |

#### Display (`LookinAttrSec_UITraitCollection_Display`)

| Attr ID Suffix    | Property                            | Type    | Enum                | Min iOS |
| ----------------- | ----------------------------------- | ------- | ------------------- | ------- |
| DisplayScale      | `traitCollection.displayScale`      | CGFloat | —                   | 8       |
| DisplayGamut      | `traitCollection.displayGamut`      | enum    | UIDisplayGamut      | 10      |
| ImageDynamicRange | `traitCollection.imageDynamicRange` | enum    | UIImageDynamicRange | 17      |

#### Device (`LookinAttrSec_UITraitCollection_Device`)

| Attr ID Suffix       | Property                               | Type | Enum                   | Min iOS |
| -------------------- | -------------------------------------- | ---- | ---------------------- | ------- |
| UserInterfaceIdiom   | `traitCollection.userInterfaceIdiom`   | enum | UIUserInterfaceIdiom   | 8       |
| ForceTouchCapability | `traitCollection.forceTouchCapability` | enum | UIForceTouchCapability | 9       |

#### Layout (`LookinAttrSec_UITraitCollection_Layout`)

| Attr ID Suffix  | Property                          | Type | Enum                              | Min iOS |
| --------------- | --------------------------------- | ---- | --------------------------------- | ------- |
| LayoutDirection | `traitCollection.layoutDirection` | enum | UITraitEnvironmentLayoutDirection | 10      |

#### Content (`LookinAttrSec_UITraitCollection_Content`)

| Attr ID Suffix               | Property                                       | Type     | Enum | Min iOS |
| ---------------------------- | ---------------------------------------------- | -------- | ---- | ------- |
| PreferredContentSizeCategory | `traitCollection.preferredContentSizeCategory` | NSString | —    | 10      |
| TypesettingLanguage          | `traitCollection.typesettingLanguage`          | NSString | —    | 17      |

## UIWindowScene Level — Expanding `LookinAttrSec_UIWindowScene_Traits`

Existing 3 attributes retained. New attributes added:

| Attr ID Suffix               | Property                                       | Type     | Enum                              | Min iOS |
| ---------------------------- | ---------------------------------------------- | -------- | --------------------------------- | ------- |
| UserInterfaceLevel           | `traitCollection.userInterfaceLevel`           | enum     | UIUserInterfaceLevel              | 13      |
| ActiveAppearance             | `traitCollection.activeAppearance`             | enum     | UIUserInterfaceActiveAppearance   | 14      |
| AccessibilityContrast        | `traitCollection.accessibilityContrast`        | enum     | UIAccessibilityContrast           | 13      |
| LegibilityWeight             | `traitCollection.legibilityWeight`             | enum     | UILegibilityWeight                | 13      |
| DisplayScale                 | `traitCollection.displayScale`                 | CGFloat  | —                                 | 13      |
| DisplayGamut                 | `traitCollection.displayGamut`                 | enum     | UIDisplayGamut                    | 13      |
| UserInterfaceIdiom           | `traitCollection.userInterfaceIdiom`           | enum     | UIUserInterfaceIdiom              | 13      |
| LayoutDirection              | `traitCollection.layoutDirection`              | enum     | UITraitEnvironmentLayoutDirection | 13      |
| PreferredContentSizeCategory | `traitCollection.preferredContentSizeCategory` | NSString | —                                 | 13      |
| SceneCaptureState            | `traitCollection.sceneCaptureState`            | enum     | UISceneCaptureState               | 17      |
| ImageDynamicRange            | `traitCollection.imageDynamicRange`            | enum     | UIImageDynamicRange               | 17      |
| TypesettingLanguage          | `traitCollection.typesettingLanguage`          | NSString | —                                 | 17      |

## Identifier Naming Convention

### UIView Level

```
Group:   LookinAttrGroup_UITraitCollection                              → @"UITraitCollection"

Sections:
  LookinAttrSec_UITraitCollection_Appearance                            → @"UITraitCollection_Appearance"
  LookinAttrSec_UITraitCollection_SizeClass                             → @"UITraitCollection_SizeClass"
  LookinAttrSec_UITraitCollection_Display                               → @"UITraitCollection_Display"
  LookinAttrSec_UITraitCollection_Device                                → @"UITraitCollection_Device"
  LookinAttrSec_UITraitCollection_Layout                                → @"UITraitCollection_Layout"
  LookinAttrSec_UITraitCollection_Content                               → @"UITraitCollection_Content"

Attributes:
  LookinAttr_UITraitCollection_Appearance_UserInterfaceStyle             → @"UITraitCollection_Appearance_UserInterfaceStyle"
  LookinAttr_UITraitCollection_Appearance_UserInterfaceLevel             → @"UITraitCollection_Appearance_UserInterfaceLevel"
  LookinAttr_UITraitCollection_Appearance_ActiveAppearance               → @"UITraitCollection_Appearance_ActiveAppearance"
  LookinAttr_UITraitCollection_Appearance_AccessibilityContrast          → @"UITraitCollection_Appearance_AccessibilityContrast"
  LookinAttr_UITraitCollection_Appearance_LegibilityWeight               → @"UITraitCollection_Appearance_LegibilityWeight"
  LookinAttr_UITraitCollection_SizeClass_HorizontalSizeClass             → @"UITraitCollection_SizeClass_HorizontalSizeClass"
  LookinAttr_UITraitCollection_SizeClass_VerticalSizeClass               → @"UITraitCollection_SizeClass_VerticalSizeClass"
  LookinAttr_UITraitCollection_Display_DisplayScale                      → @"UITraitCollection_Display_DisplayScale"
  LookinAttr_UITraitCollection_Display_DisplayGamut                      → @"UITraitCollection_Display_DisplayGamut"
  LookinAttr_UITraitCollection_Display_ImageDynamicRange                 → @"UITraitCollection_Display_ImageDynamicRange"
  LookinAttr_UITraitCollection_Device_UserInterfaceIdiom                 → @"UITraitCollection_Device_UserInterfaceIdiom"
  LookinAttr_UITraitCollection_Device_ForceTouchCapability               → @"UITraitCollection_Device_ForceTouchCapability"
  LookinAttr_UITraitCollection_Layout_LayoutDirection                    → @"UITraitCollection_Layout_LayoutDirection"
  LookinAttr_UITraitCollection_Content_PreferredContentSizeCategory      → @"UITraitCollection_Content_PreferredContentSizeCategory"
  LookinAttr_UITraitCollection_Content_TypesettingLanguage               → @"UITraitCollection_Content_TypesettingLanguage"
```

### UIWindowScene Level (additions to existing section)

```
  LookinAttr_UIWindowScene_Traits_UserInterfaceLevel                     → @"UIWindowScene_Traits_UserInterfaceLevel"
  LookinAttr_UIWindowScene_Traits_ActiveAppearance                       → @"UIWindowScene_Traits_ActiveAppearance"
  LookinAttr_UIWindowScene_Traits_AccessibilityContrast                  → @"UIWindowScene_Traits_AccessibilityContrast"
  LookinAttr_UIWindowScene_Traits_LegibilityWeight                       → @"UIWindowScene_Traits_LegibilityWeight"
  LookinAttr_UIWindowScene_Traits_DisplayScale                           → @"UIWindowScene_Traits_DisplayScale"
  LookinAttr_UIWindowScene_Traits_DisplayGamut                           → @"UIWindowScene_Traits_DisplayGamut"
  LookinAttr_UIWindowScene_Traits_UserInterfaceIdiom                     → @"UIWindowScene_Traits_UserInterfaceIdiom"
  LookinAttr_UIWindowScene_Traits_LayoutDirection                        → @"UIWindowScene_Traits_LayoutDirection"
  LookinAttr_UIWindowScene_Traits_PreferredContentSizeCategory           → @"UIWindowScene_Traits_PreferredContentSizeCategory"
  LookinAttr_UIWindowScene_Traits_SceneCaptureState                      → @"UIWindowScene_Traits_SceneCaptureState"
  LookinAttr_UIWindowScene_Traits_ImageDynamicRange                      → @"UIWindowScene_Traits_ImageDynamicRange"
  LookinAttr_UIWindowScene_Traits_TypesettingLanguage                    → @"UIWindowScene_Traits_TypesettingLanguage"
```

## New Enum Lists (LKEnumListRegistry)

| Enum Name                           | Values                                                                  |
| ----------------------------------- | ----------------------------------------------------------------------- |
| `UIUserInterfaceIdiom`              | Unspecified(-1), Phone(0), Pad(1), TV(2), CarPlay(3), Mac(5), Vision(6) |
| `UIUserInterfaceLevel`              | Unspecified(-1), Base(0), Elevated(1)                                   |
| `UIUserInterfaceActiveAppearance`   | Unspecified(-1), Inactive(0), Active(1)                                 |
| `UIAccessibilityContrast`           | Unspecified(-1), Normal(0), High(1)                                     |
| `UILegibilityWeight`                | Unspecified(-1), Regular(0), Bold(1)                                    |
| `UIForceTouchCapability`            | Unknown(0), Unavailable(1), Available(2)                                |
| `UIDisplayGamut`                    | Unspecified(-1), SRGB(0), P3(1)                                         |
| `UITraitEnvironmentLayoutDirection` | Unspecified(-1), LeftToRight(0), RightToLeft(1)                         |
| `UIImageDynamicRange`               | Unspecified(-1), Standard(0), ConstrainedHigh(1), High(2)               |
| `UISceneCaptureState`               | Unspecified(-1), Inactive(0), Active(1)                                 |

Existing `UIUserInterfaceStyle` and `UIUserInterfaceSizeClass` are already registered.

## Server-Side Category Methods

### UIView+LookinServer (new methods)

All methods follow the pattern:

```objc
- (NSInteger)lks_traitCollection_userInterfaceStyle {
    return (NSInteger)self.traitCollection.userInterfaceStyle;
}
```

For iOS version-gated properties, use `@available`:

```objc
- (NSInteger)lks_traitCollection_activeAppearance {
    if (@available(iOS 14.0, *)) {
        return (NSInteger)self.traitCollection.activeAppearance;
    }
    return -1; // Unspecified
}
```

For CGFloat properties (`displayScale`):

```objc
- (CGFloat)lks_traitCollection_displayScale {
    return self.traitCollection.displayScale;
}
```

For NSString properties (`preferredContentSizeCategory`, `typesettingLanguage`):

```objc
- (NSString *)lks_traitCollection_preferredContentSizeCategory {
    return self.traitCollection.preferredContentSizeCategory;
}
```

### UIWindowScene+LookinServer (new methods)

Same pattern, reading from `self.traitCollection`:

```objc
- (NSInteger)lks_userInterfaceLevel {
    return (NSInteger)self.traitCollection.userInterfaceLevel;
}
```

## Files to Modify

### Server/Core — dual copies synced

| #   | File                                                     | Changes                                                                             |
| --- | -------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 1   | `Sources/LookinCore/LookinAttrIdentifiers.h`             | Add 1 group + 6 section + 15 attr externs (UIView); 12 attr externs (UIWindowScene) |
| 2   | `Sources/LookinCore/LookinAttrIdentifiers.m`             | String value definitions                                                            |
| 3   | `Sources/LookinServer/Shared/LookinAttrIdentifiers.h`    | Sync with #1                                                                        |
| 4   | `Sources/LookinServer/Shared/LookinAttrIdentifiers.m`    | Sync with #2                                                                        |
| 5   | `Sources/LookinCore/LookinDashboardBlueprint.m`          | Register group/sections/attrs, metadata, section titles                             |
| 6   | `Sources/LookinServer/Shared/LookinDashboardBlueprint.m` | Sync with #5                                                                        |

### Server Category

| #   | File                                                                | Changes                                    |
| --- | ------------------------------------------------------------------- | ------------------------------------------ |
| 7   | `Sources/LookinServer/Server/Category/UIView+LookinServer.h`        | Declare 15 `lks_traitCollection_*` methods |
| 8   | `Sources/LookinServer/Server/Category/UIView+LookinServer.m`        | Implement methods                          |
| 9   | `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.h` | Declare 12 new `lks_*` methods             |
| 10  | `Sources/LookinServer/Server/Category/UIWindowScene+LookinServer.m` | Implement methods                          |

### macOS Client

| #   | File                                         | Changes                                                   |
| --- | -------------------------------------------- | --------------------------------------------------------- |
| 11  | `LookInside/Dashboard/LKEnumListRegistry.m`  | Add 10 new enum tables                                    |
| 12  | `LookInside/Manager/LKPreferenceManager.m`   | Register new sections for preference tracking             |
| 13  | `LookInside/Dashboard/LKDashboardCardView.m` | Add UITraitCollection group icon (if icon mapping exists) |

### No Changes Needed

- `LKS_AttrGroupsMaker.m` — existing `attrGroupsForLayer:` auto-handles className=UIView; `attrGroupsForWindowScene:` auto-handles className=UIWindowScene
- `LKS_HierarchyDisplayItemsMaker.m` — no hierarchy changes
- `LookinDisplayItem.h/.m` — no model changes

## Platform Guards

- All UITraitCollection code: `#if TARGET_OS_IPHONE` only
- Blueprint metadata uses `osVersion` field for minimum iOS version enforcement
- Category methods use `@available` checks for iOS 14+ / iOS 17+ properties
- `LKEnumListRegistry` entries use `MakeItemWithVersion` macro where appropriate (e.g., Vision idiom requires iOS 17)

## Key Implementation Notes

- All trait attributes are read-only (`setterString = @""`)
- `preferredContentSizeCategory` returns an `NSString` (e.g., `UICTContentSizeCategoryL`); displayed as-is with `LookinAttrTypeNSString`
- `typesettingLanguage` also returns `NSString`; may be nil, so use `hideIfNil = YES`
- `displayScale` is a CGFloat, rendered with `LookinAttrTypeFloat`
- `forceTouchCapability` is deprecated in iOS 17 but still functional; no special handling needed
- Getter selector names are auto-derived from `fullTitle` by the blueprint when `getterString` is nil; we set explicit `getterString` values since our method names use the `lks_traitCollection_*` prefix
