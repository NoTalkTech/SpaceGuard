# SpaceGuard

A macOS status bar application for disk space management with risk-based file cleanup.

## Features

- **Disk Usage Monitoring**: Real-time view of disk space usage
- **Risk-Based Classification**: Files categorized as Low, Medium, or High risk for deletion
- **Smart Cleanup**:
  - Low risk: Automatically cleaned (cache, temp files)
  - Medium risk: User confirmation required (old downloads, logs)
  - High risk: Deletion prohibited (system files, applications)
- **Status Bar Interface**: Always accessible from menu bar
- **Safe Deletion**: Progress bar and undo support
- **Native macOS Integration**: Uses system APIs only, no external dependencies

## Installation

### DMG Installer
Download the latest `.dmg` from [Releases](https://github.com/h417652303/SpaceGuard/releases) and drag to Applications.

### Build from Source
```bash
# Clone the repository
git clone https://github.com/h417652303/SpaceGuard.git
cd SpaceGuard

# Open in Xcode
open SpaceGuard.xcodeproj

# Build and run
```

## Usage

1. Click the SpaceGuard icon in the menu bar
2. View disk usage statistics
3. Review files categorized by risk level
4. Configure auto-clean settings
5. Perform cleanup with progress tracking

## Risk Classification

### High Risk (No Delete)
- System files (`/System`, `/usr`, `/bin`)
- Application bundles (`.app`)
- User home directory core files
- Files owned by root/system processes

### Medium Risk (Confirm)
- Cache files (user and system caches)
- Log files (older than 30 days)
- Downloads folder (older than 90 days)
- Temporary files
- Unused language packs

### Low Risk (Auto-clean)
- Trash contents
- Browser cache (Safari, Chrome, Firefox)
- Xcode derived data
- npm/yarn cache
- Docker/VM temporary files

## Development

### Requirements
- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

### Project Structure
```
SpaceGuard/
├── Sources/
│   ├── SpaceGuard/           # Main application
│   ├── DiskScanner/          # File system scanning
│   ├── RiskAnalyzer/         # Risk classification
│   └── Models/              # Data models
├── Tests/
└── Package.swift
```

### Building
```bash
# Build with Swift Package Manager
swift build

# Run tests
swift test

# Create Xcode project
swift package generate-xcodeproj
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Maintained by [Wallace Huang](mailto:h417652303@gmail.com)

## Acknowledgments

- Uses native macOS APIs (FileManager, Foundation, AppKit)
- Inspired by disk cleanup needs of macOS users
- Built with SwiftUI for modern macOS UI