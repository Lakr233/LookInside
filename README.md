# LookInside

A macOS UI inspector for debuggable macOS and iOS apps. Click a view, see its layer tree, frames, and resolved properties live.

![Preview](./Resources/SCR-20260330-ccud.png)

Website · [lookinside-app.com](https://lookinside-app.com)
Server library · [LookInside-Server](https://github.com/LookInsideApp/LookInside-Server)
Upstream · [QMUI/LookinServer](https://github.com/QMUI/LookinServer)

LookInside is a community continuation of [Lookin](https://github.com/QMUI/LookinServer). It ships with no telemetry, no crash upload, and no auto-update service.

---

## How it works (at a glance)

```
┌────────────┐    Peertalk over TCP loopback / USB    ┌──────────────┐
│ LookInside │ ◄────── 47164–47179 (per platform) ──► │  Your app    │
│  (macOS)   │       NSKeyedArchiver framing           │ + LookinServer│
└────────────┘                                          └──────────────┘
```

1. You embed [LookInside-Server](https://github.com/LookInsideApp/LookInside-Server) into the app you want to inspect (debug builds only).
2. You launch LookInside on your Mac.
3. LookInside auto-discovers running targets — macOS apps, iOS Simulator apps, USB-connected iOS devices.
4. You click into the live view hierarchy.

---

## Get started

### 1. Install

Grab a notarized build from the [Releases page](https://github.com/LookInsideApp/LookInside/releases) or the [website](https://lookinside-app.com).

### 2. Embed the server in your app

See [LookInside-Server](https://github.com/LookInsideApp/LookInside-Server) for the SwiftPM / CocoaPods integration. It only links into debug configurations and is wire-compatible with upstream Lookin.

### 3. Run and inspect

Launch LookInside, run your debug build, pick the target from the sidebar.

---

## Build from source

Requirements:

- macOS 14 or later
- Xcode + command-line tools
- a debuggable target app to inspect

Build the macOS app:

```bash
bash Scripts/sync-derived-source.sh
xcodebuild -skipMacroValidation \
           -project LookInside.xcodeproj \
           -scheme LookInside \
           -configuration Debug \
           -derivedDataPath /tmp/LookInsideDerivedData \
           CODE_SIGNING_ALLOWED=NO build
```

The sync step mirrors shared Swift sources from [`Sources/`](Sources/) into [`LookInside/DerivedSource`](LookInside/DerivedSource). If you change shared code, edit it under [`Sources/`](Sources/) and re-sync.

### Cut a signed local release

```bash
bash Scripts/build-and-release.sh           # auto-bumps patch + build number
bash Scripts/build-and-release.sh --version 1.2.3
```

This bumps the version, notarizes, pushes the tag, and publishes a GitHub Release from your machine.

---

## Repository layout

| Path | What lives there |
| --- | --- |
| [`LookInside/`](LookInside/) | macOS app target — AppKit shell, sidebar, hierarchy view |
| [`Sources/`](Sources/) | Canonical shared sources mirrored into the app target |
| [`Sources/LookinCore`](Sources/LookinCore) | Inspection primitives, Peertalk transport |
| [`Resources/`](Resources/) | Assets and preserved third-party license notices |

Module names like `LookinServer`, `LookinShared`, `LookinCore` are intentionally preserved from upstream Lookin to keep migrations painless.

---

## License

GPL-3.0 — see [`LICENSE`](LICENSE).

Bundled components keep their original notices in [`Resources/Licenses/`](Resources/Licenses/):

- `ReactiveObjC` — MIT
- `Peertalk` — MIT
- `LookinServer` — MIT
- `ShortCocoa` — GPL-3.0 (matches upstream Lookin)
- `Lookin` upstream client code — GPL-3.0

## Acknowledgements

Built on top of [`QMUI/LookinServer`](https://github.com/QMUI/LookinServer) and [`CocoaUIInspector/Lookin`](https://github.com/CocoaUIInspector/Lookin). Thank you to the original authors.
