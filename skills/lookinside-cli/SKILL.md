---
name: lookinside-cli
description: Use this skill when working with the LookInside command-line tool or embedding the LookinServer runtime into a host app. Trigger on requests involving `lookinside list`, `inspect`, `hierarchy`, `export`, target IDs, hierarchy trees, hierarchy JSON payloads, packaging `LookinServerDynamic`, or porting a Lookin-style integration from iOS/macOS to another platform such as Android or HarmonyOS.
---

# LookInside CLI and Integration

Use the repository's CLI to inspect live macOS, iOS Simulator, and USB-connected targets, and use the same repository to embed or package `LookinServer` for host apps.

## Quick Start

Work from the repository root so SwiftPM can find `Package.swift`.

Prefer the built binary for repeat commands:

```bash
.build/debug/lookinside list
```

If the binary is missing, build it first:

```bash
swift build -c debug --product lookinside
```

## CLI Workflow

### 1. Discover targets

Start with `list`. It is also the default subcommand.

Use text mode for quick terminal inspection:

```bash
.build/debug/lookinside list
```

Use JSON when you need a stable shape for docs, parsing, or follow-up automation:

```bash
.build/debug/lookinside list --format json
```

Useful filters:

- `--transport mac`, `--transport simulator`, or `--transport usb`
- `--name-contains <text>`
- `--bundle-id <bundle-id>`
- `--ids-only` for text mode pipelines

`targetID` values are runtime-discovered opaque strings like `mac:47170:7268387651031256382` or `simulator:47164:1774294178`.

### 2. Inspect one target

Use `inspect` to print metadata for a target returned by `list`.

```bash
.build/debug/lookinside inspect --target <id>
.build/debug/lookinside inspect --target <id> --format json
```

Prefer JSON when the user asks what fields exist or wants machine-readable output.

### 3. Fetch a live hierarchy

Use tree mode for human-readable terminal output:

```bash
.build/debug/lookinside hierarchy --target <id>
```

Use JSON for structured analysis:

```bash
.build/debug/lookinside hierarchy --target <id> --format json
```

Use `--output` when the result is too large for the terminal or the user wants an artifact:

```bash
.build/debug/lookinside hierarchy --target <id> --output /tmp/sample-tree.txt
```

### 4. Export a reusable snapshot

Use JSON when another tool should consume the hierarchy payload:

```bash
.build/debug/lookinside export --target <id> --output /tmp/sample.json --format json
```

Use archive output when the snapshot should be opened later in LookInside:

```bash
.build/debug/lookinside export --target <id> --output /tmp/sample.lookinside
```

Format rules:

- `--format auto` infers from the file extension
- JSON exports must use `.json`
- archive exports must use `.archive`, `.lookin`, or `.lookinside`
- archive output with no extension becomes `.lookinside`

### 5. Validate against a running host app

After launching a host app that embeds `LookinServer`, use `list`, `inspect`, `hierarchy`, or `export` from the CLI to validate the end-to-end flow.

## Embedding and Porting `LookinServer`

For Apple-platform host apps you control, prefer normal source or framework integration and call `LookinServerStart()` once during startup.

Use `bash Scripts/package-lookinserver.sh` when you need packaged artifacts instead of a direct SwiftPM/Xcode integration. The script produces a `LookinServer.xcframework` plus per-SDK `LookinServer.dylib` outputs under `build/lookinserver/`.

Treat the packaged dylib as an advanced developer path. It can be useful in controlled environments that support runtime code injection into the target process, but this skill should not assume that injection is portable, review-safe, or allowed on stock devices or store builds.

For Android, HarmonyOS, or other non-Apple ports, keep the protocol and output compatibility where it helps, but reimplement the platform adapters. The UIKit/AppKit-specific categories in `Sources/LookinServer/Server/Category` are not directly portable.

Preserve compatibility names such as `LookinServer`, `LookinShared`, and `LookinCore` when it reduces migration friction for existing hosts or tooling.

## References

Read [output-shapes.md](references/output-shapes.md) when the user asks what the data looks like, wants example snippets for docs, or needs to know which fields exist in JSON output.

Read [integration-porting.md](references/integration-porting.md) when the user is embedding `LookinServer` into an open-source host, packaging the dynamic library, or moving a Lookin-style integration from iOS/macOS to Android, HarmonyOS, or another platform.

## Troubleshooting

- If `swift run lookinside ...` says `Could not find Package.swift`, change into the repo root first.
- If live discovery is flaky, re-run `list` immediately before `inspect`, `hierarchy`, or `export`.
- Prefer `.build/debug/lookinside` over repeated `swift run` calls once the CLI is built.
- Expect hierarchy JSON to be large; write it to a file when you only need a sample or want to inspect it incrementally.
- If the client rejects a target because of version compatibility, update the embedded `LookinServer` integration from this repository before changing the desktop app or CLI assumptions.
- For cross-platform ports, ship read-only inspection first, then add editing or screenshot fidelity work after the hierarchy transport is stable.
