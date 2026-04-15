# SpaceGuard

[![Build Status](https://github.com/NoTalkTech/SpaceGuard/actions/workflows/release.yml/badge.svg)](https://github.com/NoTalkTech/SpaceGuard/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/NoTalkTech/SpaceGuard?display_name=tag)](https://github.com/NoTalkTech/SpaceGuard/releases/latest)
[![License](https://img.shields.io/github/license/NoTalkTech/SpaceGuard)](https://github.com/NoTalkTech/SpaceGuard/blob/main/LICENSE)

SpaceGuard is a macOS menu bar cleanup app built around one constraint: cleanup must stay explainable and reversible enough that users can trust it.

The app combines:

- rule-driven scanning for general cleanup
- scenario-driven cleanup for known cache locations
- explicit risk classification before deletion
- a review UI that stays usable even when the candidate set is very large

It is implemented as a Swift Package Manager executable and uses native macOS APIs.

## Core Product Model

SpaceGuard treats deletion as a safety problem first.

- Low risk: caches, temporary files, disposable app data
- Medium risk: items that may be safe but should be reviewed
- High risk: system files, application bundles, protected or critical data

Cleanup behavior is driven by:

- `CleanupRules`
- include and exclude paths
- file type rules
- custom risk overrides
- scenario-specific safeguards

## Main User Flows

### Status Bar Actions

The menu bar exposes a minimal foreground workflow:

- `Analyze Disk`
- `Quick Cleanup`
- `Settings...`

`Analyze Disk` and `Quick Cleanup` now report foreground state directly in the menu bar so the user sees:

- immediate activity text
- terminal status text
- completion state without relying on notifications

The user can open the main window when deeper review is needed, but the first feedback stays in the menu bar.

### Main Window

The main window is intentionally small and centered on the cleanup loop:

- Cleanup
- Settings
- History

- `Cleanup` is the operational control center for scan and quick cleanup
- `Settings` contains the rule and scope configuration needed to support cleanup
- `History` provides lightweight auditability for past runs

### Cleanup Confirmation

The cleanup confirmation flow is designed for large result sets.

It supports:

- per-risk grouping
- representative directories
- representative large files
- direct `Open` actions for quick Finder inspection

The review UI is meant to support a deletion decision, not act as a full file browser.

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

## Architecture

The codebase is a small app shell over a service-heavy core.

- `Sources/App`
  - menu bar lifecycle
  - settings window creation
  - top-level app wiring via `AppDelegate` and `AppDependencies`
- `Sources/Models`
  - rules, scenarios, file metadata, history, safety metadata
- `Sources/Services`
  - scanning, risk analysis, history, persistence, estimation, previewing
- `Sources/Services/Engine`
  - cleanup execution, deletion decisions, rule conflict handling
- `Sources/Views`
  - cleanup and unified settings UI
  - cleanup confirmation and progress UI
  - history UI
  - shared rows and sections

At a high level:

1. `DiskScanner` discovers files and disk usage
2. `RiskAnalyzer` assigns risk and reason metadata
3. `RuleManager` validates and resolves rule conflicts
4. `DeletionDecider` decides skip vs confirm vs delete
5. `CleanupEngine` executes cleanup
6. `CleanupHistoryManager` records completed operations
7. `ProgressTracker` exposes scan/cleanup state to the UI

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

## Requirements

- macOS 12 or newer
- Swift 5.9 or newer
- Xcode 15 or newer for IDE development

## Build And Run

```bash
git clone https://github.com/NoTalkTech/SpaceGuard.git
cd SpaceGuard
swift build
swift run
```

`swift run` launches the menu bar app from the SwiftPM build output.

If you want to launch the generated app bundle directly:

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

For manual regression of the status bar actions and cleanup confirmation flow, see:

- [docs/status-bar-regression.md](docs/status-bar-regression.md)

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

## Contributor Notes

- This is a SwiftPM executable target, not an Xcode project-based app target.
- Keep UI thin. Most behavior should stay in `Services` and `Services/Engine`.
- `CleanupRules` remains the center of rule-driven behavior.
- Rule-based cleanup and scenario-based cleanup must stay coherent.
- If you touch operational flows, validate both the foreground UI and the underlying state transitions.
- Prefer tests at the service or state-management layer when possible.

## License

MIT. See [LICENSE](LICENSE).
