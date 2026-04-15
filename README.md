# SpaceGuard

[![Build Status](https://github.com/NoTalkTech/SpaceGuard/actions/workflows/release.yml/badge.svg)](https://github.com/NoTalkTech/SpaceGuard/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/NoTalkTech/SpaceGuard?display_name=tag)](https://github.com/NoTalkTech/SpaceGuard/releases/latest)
[![License](https://img.shields.io/github/license/NoTalkTech/SpaceGuard)](https://github.com/NoTalkTech/SpaceGuard/blob/main/LICENSE)

SpaceGuard is a macOS menu bar cleanup app built around one rule: cleanup must stay explainable, reviewable, and safe enough to trust.

It is designed for users who want to reclaim disk space without turning cleanup into a black box. SpaceGuard keeps operational actions in the menu bar, classifies files by risk before deletion, and limits automation to flows that remain low risk.

## Why SpaceGuard

Most cleanup tools optimize for aggressiveness. SpaceGuard optimizes for trust.

- low-risk files can be cleaned automatically
- medium-risk files must be reviewed or confirmed
- high-risk files are blocked from deletion by policy
- active work reports status directly in the menu bar

The goal is simple: make disk cleanup useful without making it opaque.

## How It Works

SpaceGuard exposes a small foreground workflow from the menu bar:

- `Analyze Disk`
- `Quick Cleanup`
- `Settings...`

In practice the flow is:

1. Use `Analyze Disk` to inspect candidate files.
2. Use `Quick Cleanup` for known low-risk cleanup paths.
3. Review or confirm anything that should not be deleted blindly.

While work is in progress, the menu bar shows live status and progress so the first feedback stays in place instead of being pushed into a larger control panel.

## Safety Model

SpaceGuard treats deletion as a safety problem first.

- Low risk: caches, temporary files, disposable app data
- Medium risk: items that may be safe but should still be reviewed
- High risk: system files, application bundles, protected or critical data

Cleanup behavior is driven by:

- `CleanupRules`
- include and exclude paths
- file type rules
- custom risk overrides
- scenario-specific safeguards

## Current UX Model

The current product model is intentionally narrow.

- The menu bar is the operational surface for `Analyze Disk` and `Quick Cleanup`
- `Settings...` is configuration-only
- active operations surface live progress in the menu
- cleanup confirmation is designed for decision support, not full file browsing

This keeps the product split clear: operations in the menu bar, policy in settings.

## Supported Cleanup Scenarios

The scenario layer currently covers:

- Trash
- macOS wallpaper cache
- JetBrains caches
- JetBrains logs
- Electron ShipIt update cache
- Homebrew cache
- npm cache
- pip cache

Some scenarios are path based. Others rely on workflow-specific cleanup logic.

## Installation

Download the latest DMG from [Releases](https://github.com/NoTalkTech/SpaceGuard/releases/latest), then:

1. Open the DMG
2. Drag `SpaceGuard.app` to `Applications`
3. Launch it and use the menu bar item

## Build From Source

Requirements:

- macOS 12 or newer
- Swift 5.9 or newer
- Xcode 15 or newer for IDE development

Build and run:

```bash
git clone https://github.com/NoTalkTech/SpaceGuard.git
cd SpaceGuard
swift build
swift run
```

`swift run` launches the menu bar app from the SwiftPM build output.

If you want to open the generated app bundle directly:

```bash
open /Users/biyu.huang/code/SpaceGuard/SpaceGuard.app
```

## Validation

Run the full test suite:

```bash
swift test
```

Run the most relevant targeted tests for menu-bar-triggered cleanup state:

```bash
swift test --filter 'SpaceGuardTests\.ProgressTrackerTests'
```

For manual regression of the status bar actions and cleanup confirmation flow, see [docs/status-bar-regression.md](docs/status-bar-regression.md).

## Packaging

The `scripts/` directory contains helper scripts for distribution:

- `scripts/create-app-bundle.sh`
- `scripts/install.sh`
- `scripts/sign.sh`
- `scripts/make-dmg.sh`
- `scripts/IconGenerator.swift`

Example:

```bash
./scripts/create-app-bundle.sh
./scripts/install.sh
```

## Architecture

The codebase is a small app shell over a service-heavy core.

- `Sources/App`
  Menu bar lifecycle, settings window creation, and top-level wiring via `AppDelegate` and `AppDependencies`
- `Sources/Models`
  Rules, scenarios, file metadata, history, and safety metadata
- `Sources/Services`
  Scanning, risk analysis, history, persistence, estimation, and previewing
- `Sources/Services/Engine`
  Cleanup execution, deletion decisions, and rule conflict handling
- `Sources/Views`
  Cleanup, settings, confirmation, progress, history, and shared UI components

At a high level:

1. `DiskScanner` discovers files and disk usage
2. `RiskAnalyzer` assigns risk and reason metadata
3. `RuleManager` validates and resolves rule conflicts
4. `DeletionDecider` decides skip vs confirm vs delete
5. `CleanupEngine` executes cleanup
6. `CleanupHistoryManager` records completed operations
7. `ProgressTracker` exposes scan and cleanup state to the UI

## Project Layout

```text
SpaceGuard/
├── Package.swift
├── Sources/
│   ├── App/
│   ├── Models/
│   ├── Resources/
│   ├── Services/
│   │   ├── Engine/
│   │   └── Protocols/
│   └── Views/
│       ├── Cleanup/
│       ├── Dialogs/
│       ├── History/
│       ├── Settings/
│       └── Shared/
├── Tests/
├── docs/
└── scripts/
```

## Contributor Notes

- This is a SwiftPM executable target, not an Xcode project-based app target
- Keep UI thin; most behavior should stay in `Services` and `Services/Engine`
- `CleanupRules` remains the center of rule-driven behavior
- Rule-based cleanup and scenario-based cleanup must stay coherent
- If you touch operational flows, validate both the foreground UI and the underlying state transitions
- Prefer tests at the service or state-management layer when possible

## License

MIT. See [LICENSE](LICENSE).
