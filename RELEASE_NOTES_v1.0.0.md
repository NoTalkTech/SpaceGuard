# SpaceGuard v1.0.0 Release Notes

## 🎉 First Release

SpaceGuard is now available as a stable macOS application for disk space management with risk-based file cleanup.

## 📦 What's Included

- **SpaceGuard-1.0.0.dmg** - macOS Disk Image installer
- **Source code** - Complete Swift project for building from source

## 🚀 Features

### Core Functionality
- ✅ Disk usage monitoring in status bar
- ✅ Risk-based file classification (Low/Medium/High)
- ✅ Safe cleanup with progress tracking
- ✅ Status bar menu interface
- ✅ SwiftUI settings window
- ✅ Native macOS APIs only (no external dependencies)

### Risk Classification System
- **High Risk**: System files, applications, user documents (no delete)
- **Medium Risk**: Caches, logs, old downloads (user confirmation required)
- **Low Risk**: Browser cache, temp files, trash (auto-clean)

### User Interface
- Status bar icon with disk usage percentage
- Settings window with tabbed interface (General, Cleanup, Disk Info)
- Progress tracking during scans and cleanup
- System notifications for completed operations

## 📋 Installation

### Option 1: DMG Installer (Recommended)
1. Download `SpaceGuard-1.0.0.dmg`
2. Double-click to mount the disk image
3. Drag `SpaceGuard.app` to the `Applications` folder
4. Launch SpaceGuard from Applications or Spotlight

### Option 2: Build from Source
```bash
git clone https://github.com/NoTalkTech/SpaceGuard.git
cd SpaceGuard
./scripts/create-app-bundle.sh
# Drag SpaceGuard.app to Applications
```

## 🛠️ Technical Details

- **Platform**: macOS 12.0+
- **Language**: Swift 5.9
- **UI**: SwiftUI + AppKit
- **Distribution**: DMG with .app bundle
- **Dependencies**: None (pure macOS APIs)

## 🔧 Included Scripts

The repository includes helper scripts for developers:
- `scripts/create-app-bundle.sh` - Creates .app bundle from SwiftPM build
- `scripts/install.sh` - Interactive installation script
- `scripts/make-dmg.sh` - Creates DMG for distribution
- `scripts/IconGenerator.swift` - Generates app icons

## 📄 Documentation

Full documentation available in [README.md](README.md)

## 🐛 Known Issues

- First launch requires notification permission
- Some system directories may require admin access
- Large disk scans may take several minutes

## 🔄 What's Next

- Advanced cleanup rules
- File preview before deletion
- Scheduled cleanup
- Cloud storage integration

## 👥 Credits

**Maintainer**: Wallace Huang (h417652303@gmail.com)

**License**: MIT - See [LICENSE](LICENSE)

**Repository**: https://github.com/NoTalkTech/SpaceGuard

---

*Thank you for using SpaceGuard! Please report any issues on GitHub.*