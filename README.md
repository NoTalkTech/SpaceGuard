# SpaceGuard

SpaceGuard is a macOS menu bar app for disk cleanup with explicit risk controls.

It combines two cleanup modes:

- Rule-based scanning for general file cleanup
- Scenario-based cleanup for known cache locations such as JetBrains, Homebrew, npm, pip, wallpaper cache, and Trash

The app is built as a Swift Package Manager executable and uses native macOS APIs only.

## What It Does

- Monitors disk usage from the menu bar
- Scans files and assigns a risk level: low, medium, or high
- Auto-cleans low-risk files
- Requires confirmation for medium-risk files
- Blocks deletion of high-risk files
- Supports presets for common cleanup strategies
- Tracks cleanup history
- Provides dedicated cleanup scenarios for developer and system caches

## Risk Model

SpaceGuard treats deletion as a safety problem first.

- Low risk: caches, temporary files, Trash, known disposable app data
- Medium risk: old downloads, logs, user data that may be recoverable but should be reviewed
- High risk: system files, application bundles, critical user data, explicitly protected paths

The exact behavior is controlled by `CleanupRules`, custom overrides, include/exclude paths, file type rules, and scenario-specific safeguards.

## Architecture

The codebase is organized around a small app shell and a service-heavy core:

- `Sources/App`
  - app entry point
  - menu bar lifecycle
  - settings window and notifications
- `Sources/Models`
  - `CleanupRules`
  - cleanup presets and scenarios
  - history records, rule conflicts, scheduling metadata
- `Sources/Services`
  - `DiskScanner` for file discovery and disk stats
  - `RiskAnalyzer` for risk classification and assessment
  - `CleanupScenariosDetector` for known cache locations
  - `CleanupPresetManager` for preset composition
  - `ProgressTracker` for scan and cleanup state
  - persistence and history services
- `Sources/Services/Engine`
  - `CleanupEngine`
  - `DeletionDecider`
  - `RuleManager`
  - `FileDeleter`
- `Sources/Views`
  - settings tabs
  - cleanup dialogs
  - preset UI
  - history and shared components

At a high level, the main flow is:

1. `DiskScanner` discovers files
2. `RiskAnalyzer` assigns risk and assessment metadata
3. `RuleManager` validates and resolves rule conflicts
4. `DeletionDecider` determines whether a file should be skipped, confirmed, or deleted
5. `CleanupEngine` executes cleanup and records results

## Cleanup Presets

Built-in presets currently include:

- `safe`: conservative cleanup for most users
- `developer`: focuses on developer caches and logs
- `advanced`: broad cleanup across all supported scenarios
- `custom`: user-defined preset rules

Presets are merged into the active rule set rather than replacing the entire configuration blindly.

## Supported Cleanup Scenarios

The scenario system currently detects or cleans:

- Trash
- macOS wallpaper cache
- JetBrains caches
- JetBrains logs
- Electron ShipIt update cache
- Homebrew cache
- npm cache
- pip cache

Some scenarios are path-based. Others use command-line cleanup flows where appropriate.

## Requirements

- macOS 12 or newer
- Swift 5.9 or newer
- Xcode 15 or newer if you want IDE support

## Build

```bash
git clone https://github.com/NoTalkTech/SpaceGuard.git
cd SpaceGuard
swift build
```

Run tests:

```bash
swift test
```

## Run

For local development:

```bash
swift run
```

This launches the menu bar app from the SwiftPM build output.

## Packaging

The `scripts/` directory contains helper scripts for app distribution:

- `scripts/create-app-bundle.sh`: create a `.app` bundle from the SwiftPM build
- `scripts/install.sh`: install interactively into `/Applications`
- `scripts/sign.sh`: sign the generated app bundle
- `scripts/make-dmg.sh`: build a DMG for distribution
- `scripts/IconGenerator.swift`: generate app icons

Example:

```bash
./scripts/create-app-bundle.sh
./scripts/install.sh
```

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
└── scripts/
```

## Notes For Contributors

- The app is a SwiftPM executable target, not an Xcode project-based app.
- Core cleanup logic lives in `Services` and `Services/Engine`; UI code should stay thin.
- `CleanupRules` is the center of rule-driven behavior.
- Scenario cleanup and rule-driven cleanup coexist; changes should keep both flows coherent.
- Prefer adding tests at the service layer when modifying cleanup logic.

## License

MIT. See [LICENSE](LICENSE).
