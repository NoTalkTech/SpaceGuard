# SpaceGuard

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
- built-in cleanup presets
- scenario-specific safeguards

## Main User Flows

### Status Bar Actions

The menu bar exposes a minimal foreground workflow:

- `Analyze Disk`
- `Quick Cleanup`
- `Settings...`

`Analyze Disk` and `Quick Cleanup` now route into the `Cleanup` settings tab so the user sees:

- live progress
- terminal status text
- in-window completion banners

This avoids a dead-feeling UX when macOS notifications are unavailable or ignored.

### Settings-Driven Cleanup

The main settings window contains tabs for:

- General
- Cleanup
- File Types
- Risk Management
- Disk Info
- Advanced
- Preset Cleanup
- History
- Statistics

The `Cleanup` tab is the operational control center for scan and quick cleanup.

### Cleanup Confirmation

The cleanup confirmation flow is designed for large result sets.

It supports:

- per-risk grouping
- directory-first review mode
- file-level review mode
- search and sorting
- paged loading instead of rendering every row at once
- inline directory expansion to inspect files in place
- directory utility actions such as `Open` and `Copy Path`

This prevents the app from collapsing under very large candidate lists while still letting the user inspect what will be removed.

### Preset Cleanup

Built-in presets currently include:

- `safe`: conservative cleanup for most users
- `developer`: developer cache focused cleanup
- `advanced`: broader cleanup across supported scenarios
- `custom`: user-defined rules

Presets are merged into the active rule set instead of blindly replacing the entire configuration.

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
  - rules, presets, scenarios, file metadata, history, safety metadata
- `Sources/Services`
  - scanning, risk analysis, history, persistence, estimation, previewing
- `Sources/Services/Engine`
  - cleanup execution, deletion decisions, rule conflict handling
- `Sources/Views`
  - settings tabs
  - cleanup confirmation and progress UI
  - preset management UI
  - history/statistics UI
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
│       ├── Presets/
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
swift test --filter 'SpaceGuardTests\.(CleanupPresetManagerTests|ProgressTrackerTests)'
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
