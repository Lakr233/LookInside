# LookinServer Integration and Porting

Use this reference when the task is about embedding `LookinServer`, packaging the runtime, or porting a Lookin-style host integration from iOS/macOS to another platform.

## Current Repository Boundaries

- Public desktop product name: `LookInside`
- Compatibility runtime names intentionally preserved: `LookinServer`, `LookinShared`, `LookinCore`
- Public C entry point for host startup: `LookinServerStart()`
- Dynamic packaging script: `bash Scripts/package-lookinserver.sh`
- Minimal Apple host samples were removed from this repository.

## Integration Modes

### 1. Source or package integration

Default path for open-source hosts you control:

- link `LookinServer`
- call `LookinServerStart()` once during startup
- validate from the desktop app or CLI

This is the safest path because the host, runtime, and protocol version stay in the same source tree.

### 2. Packaged framework or dylib

Use this when the host cannot consume the repository directly and you need a distributable Apple artifact.

```bash
bash Scripts/package-lookinserver.sh
```

The script stages:

- `build/lookinserver/LookinServer.xcframework`
- `build/lookinserver/iphoneos/LookinServer.dylib`
- `build/lookinserver/iphonesimulator/LookinServer.dylib`

Prefer the framework or xcframework for normal app integration.

Treat the dylib as an advanced option for developer-controlled instrumentation environments. It may be injected where the target process and platform policy allow it, but the skill should not default to this path and should avoid presenting it as a stock-device or app-store-ready technique.

## Minimal Startup Pattern

Objective-C host:

```objc
extern void LookinServerStart(void);

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    LookinServerStart();
}
```

Swift host:

```swift
import LookinServer

@_silgen_name("LookinServerStart")
private func LookinServerStartBridge()

func applicationDidFinishLaunching(_ notification: Notification) {
    LookinServerStartBridge()
}
```

Use the startup snippets above as the minimal host pattern.

## What Is Portable vs. What Must Be Rebuilt

Usually portable or worth preserving:

- protocol and hierarchy payload shape used by the desktop app and CLI
- naming compatibility for `LookinServer`, `LookinShared`, and `LookinCore`
- version handshake expectations between client and server
- archive and JSON export semantics when backward compatibility matters

Platform-specific and usually not portable as-is:

- UIKit/AppKit view and layer traversal
- screenshot capture implementation
- event handling and target discovery
- runtime metadata extraction for views, controllers, or render nodes
- edit/mutation support for live objects

In this repository, `Sources/LookinServer/Server/Category` is strongly tied to Apple UI frameworks. For Android, HarmonyOS, or other platforms, treat those files as behavior to replicate rather than code to reuse.

## Porting Strategy for Android or HarmonyOS

Start with compatibility goals, not source-level copying.

1. Keep the desktop-side protocol stable enough that `lookinside inspect`, `hierarchy`, and `export` remain useful.
2. Recreate a platform-native node walker for the target UI tree.
3. Emit equivalent app metadata: name, bundle/package identifier, device description, OS description, server version.
4. Emit a recursive hierarchy payload with stable node identity, geometry, visibility, and children.
5. Add screenshot capture only after hierarchy correctness is reliable.
6. Add mutation/edit operations last because they are the most platform-specific and easiest to get wrong.

Practical platform mapping:

- iOS/macOS `UIView` or `NSView` tree -> Android `View` tree or HarmonyOS UI tree
- `CALayer` details -> platform render-node or composition metadata where available
- bundle identifier -> package or app identifier
- simulator/usb/mac transport -> whatever discovery and connection model the new platform can expose to the desktop client

## Guidance for Open-Source Host Apps

- Prefer integrating into the host's existing app lifecycle instead of adding a parallel bootstrap path.
- If the host already has debug menus, developer tooling, or plugin entry points, start there.
- Keep the first version read-only and clearly gated behind debug/developer builds.
- Do not claim full parity with the Apple implementation until hierarchy, screenshots, and edit flows are all validated independently.

## Validation Loop

After embedding or porting:

1. Run the target app.
2. Use `lookinside list` to confirm discovery.
3. Use `lookinside inspect --target <id>` to confirm metadata and version handshake.
4. Use `lookinside hierarchy --target <id> --format json` and compare the payload against `output-shapes.md`.
5. Use `lookinside export --target <id> --output /tmp/sample.lookinside` to verify archive generation.
