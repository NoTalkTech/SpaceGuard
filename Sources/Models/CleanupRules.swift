import Foundation

struct CleanupRules: Codable {
    var autoCleanLowRisk: Bool = true
    var confirmMediumRisk: Bool = true
    var neverDeleteHighRisk: Bool = true

    // Age-based rules
    var deleteDownloadsOlderThanDays: Int = 90
    var deleteLogsOlderThanDays: Int = 30
    var deleteCacheOlderThanDays: Int = 7

    // Size-based rules
    var minimumFileSizeToConsider: Int64 = 1024 * 1024 // 1 MB
    var skipFilesLargerThan: Int64 = 1024 * 1024 * 1024 // 1 GB

    // Specific locations to include/exclude
    var includeLocations: [String] = [
        NSHomeDirectory() + "/Library/Caches",
        NSHomeDirectory() + "/Downloads",
        "/Library/Caches",
        "/var/tmp",
        "/tmp"
    ]

    var excludeLocations: [String] = [
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Pictures",
        NSHomeDirectory() + "/Movies",
        NSHomeDirectory() + "/Music",
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/Applications"
    ]

    // App-specific caches
    var appCachesToClean: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.operasoftware.Opera",
        "com.microsoft.edgemac",
        "com.apple.dt.Xcode",
        "com.apple.AppStore",
        "com.apple.iTunes",
        "com.spotify.client",
        "com.tinyspeck.slackmacgap",
        "com.microsoft.VSCode",
        "com.jetbrains.intellij",
        "com.jetbrains.pycharm",
        "com.jetbrains.goland",
        "com.jetbrains.webstorm",
        "com.jetbrains.rubymine",
        "com.jetbrains.datagrip",
        "com.jetbrains.clion",
        "com.jetbrains.resharper"
    ]

    // Advanced rules
    var fileTypeRules: FileTypeRules = FileTypeRules()
    var customRiskOverrides: [CustomRiskOverride] = []
    var exclusionPatterns: [String] = []
    var scheduledCleanup: ScheduledCleanup? = nil

    // Preset management
    var activePreset: CleanupPreset? = nil
    var appliedPresets: [CleanupPreset] = []

    enum CodingKeys: String, CodingKey {
        case autoCleanLowRisk
        case confirmMediumRisk
        case neverDeleteHighRisk
        case deleteDownloadsOlderThanDays
        case deleteLogsOlderThanDays
        case deleteCacheOlderThanDays
        case minimumFileSizeToConsider
        case skipFilesLargerThan
        case includeLocations
        case excludeLocations
        case appCachesToClean
        case fileTypeRules
        case customRiskOverrides
        case exclusionPatterns
        case scheduledCleanup
        case activePreset
        case appliedPresets
    }

    // MARK: - Persistence (delegates to RulesPersistenceService)

    static func load() -> CleanupRules {
        RulesPersistenceService().loadRules()
    }

    func save() {
        RulesPersistenceService().saveRules(self)
    }

    func shouldIncludeFile(at path: String) -> Bool {
        // Check if in exclude locations
        for exclude in excludeLocations {
            if path.hasPrefix(exclude) {
                return false
            }
        }

        // Check exclusion patterns
        if matchesExclusionPattern(path) {
            return false
        }

        // Check if in include locations
        for include in includeLocations {
            if path.hasPrefix(include) {
                return isFileTypeAllowed(path)
            }
        }

        // Default: include files from home directory (user files)
        if path.hasPrefix(NSHomeDirectory()) {
            return isFileTypeAllowed(path)
        }

        return false
    }

    func isAppCache(_ path: String) -> Bool {
        for appCache in appCachesToClean {
            if path.contains(appCache) {
                return true
            }
        }
        return false
    }

    // Check if file matches any exclusion pattern
    func matchesExclusionPattern(_ path: String) -> Bool {
        for pattern in exclusionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: path.utf16.count)
                if regex.firstMatch(in: path, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    // Get custom risk override for a path
    func getCustomRiskOverride(for path: String) -> RiskLevel? {
        for override in customRiskOverrides {
            if path.hasPrefix(override.path) {
                return override.riskLevel
            }
        }
        return nil
    }

    // Check if file type is allowed
    func isFileTypeAllowed(_ path: String) -> Bool {
        let fileExtension = (path as NSString).pathExtension.lowercased()

        // Check blacklist
        if fileTypeRules.blacklistedExtensions.contains(fileExtension) {
            return false
        }

        // Check whitelist (if not empty, only allow listed extensions)
        if !fileTypeRules.whitelistedExtensions.isEmpty {
            return fileTypeRules.whitelistedExtensions.contains(fileExtension)
        }

        return true
    }

    // MARK: - Rule Conflict Detection and Resolution

    /// Check for rule conflicts and return descriptions of any found
    func detectConflicts() -> [RuleConflict] {
        var conflicts: [RuleConflict] = []

        // 1. Check for path inclusion/exclusion conflicts
        for include in includeLocations {
            for exclude in excludeLocations {
                if include.hasPrefix(exclude) || exclude.hasPrefix(include) {
                    conflicts.append(RuleConflict(
                        type: .pathInclusionExclusion,
                        description: "Path '\(include)' is both included and excluded (conflicts with '\(exclude)')",
                        severity: .high
                    ))
                }
            }
        }

        // 2. Check for file type rule conflicts
        for ext in fileTypeRules.whitelistedExtensions {
            if fileTypeRules.blacklistedExtensions.contains(ext) {
                conflicts.append(RuleConflict(
                    type: .fileTypeRule,
                    description: "File extension '\(ext)' is both whitelisted and blacklisted",
                    severity: .medium
                ))
            }
        }

        // 3. Check for custom risk override conflicts with system paths
        for customOverride in customRiskOverrides {
            if isSystemFile(customOverride.path) && customOverride.riskLevel != .high {
                conflicts.append(RuleConflict(
                    type: .customRiskOverride,
                    description: "Custom risk override for system path '\(customOverride.path)' sets risk to \(customOverride.riskLevel), but system files should typically be high risk",
                    severity: .high
                ))
            }
        }

        // 4. Check for unreasonable age thresholds
        if deleteDownloadsOlderThanDays < 1 {
            conflicts.append(RuleConflict(
                type: .ageThreshold,
                description: "Download age threshold (\(deleteDownloadsOlderThanDays) days) is too low and may delete recent files",
                severity: .medium
            ))
        }

        if deleteCacheOlderThanDays < 0 {
            conflicts.append(RuleConflict(
                type: .ageThreshold,
                description: "Cache age threshold (\(deleteCacheOlderThanDays) days) is negative",
                severity: .high
            ))
        }

        return conflicts
    }

    /// Resolve conflicts by applying predefined resolution strategies
    mutating func resolveConflicts() {
        // 1. Resolve file type conflicts: blacklist takes precedence over whitelist
        var resolvedWhitelist = fileTypeRules.whitelistedExtensions
        for ext in fileTypeRules.blacklistedExtensions {
            resolvedWhitelist.removeAll { $0 == ext }
        }
        fileTypeRules.whitelistedExtensions = resolvedWhitelist

        // 2. Resolve path conflicts: exclusion takes precedence over inclusion
        // (This is already handled in shouldIncludeFile method)

        // 3. Ensure system files are always high risk
        for i in 0..<customRiskOverrides.count {
            if isSystemFile(customRiskOverrides[i].path) {
                customRiskOverrides[i].riskLevel = .high
            }
        }

        // 4. Validate age thresholds
        deleteDownloadsOlderThanDays = max(1, deleteDownloadsOlderThanDays)
        deleteLogsOlderThanDays = max(0, deleteLogsOlderThanDays)
        deleteCacheOlderThanDays = max(0, deleteCacheOlderThanDays)
    }

    /// Check if a path is a system file (helper for conflict detection)
    private func isSystemFile(_ path: String) -> Bool {
        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/Library", "/Applications/Utilities"]
        return systemPaths.contains { path.hasPrefix($0) }
    }

    /// Apply a preset to these rules
    mutating func applyPreset(_ preset: CleanupPreset) {
        let presetManager = CleanupPresetManager()
        let presetRules = presetManager.getPresetRules(preset)

        // Apply preset rules (simplified merging)
        self.autoCleanLowRisk = presetRules.autoCleanLowRisk
        self.confirmMediumRisk = presetRules.confirmMediumRisk
        self.neverDeleteHighRisk = presetRules.neverDeleteHighRisk

        // Merge age thresholds (take smaller value, i.e., more aggressive cleaning)
        self.deleteDownloadsOlderThanDays = min(self.deleteDownloadsOlderThanDays, presetRules.deleteDownloadsOlderThanDays)
        self.deleteLogsOlderThanDays = min(self.deleteLogsOlderThanDays, presetRules.deleteLogsOlderThanDays)
        self.deleteCacheOlderThanDays = min(self.deleteCacheOlderThanDays, presetRules.deleteCacheOlderThanDays)

        // Merge size thresholds (take smaller value, i.e., consider smaller files)
        self.minimumFileSizeToConsider = min(self.minimumFileSizeToConsider, presetRules.minimumFileSizeToConsider)
        self.skipFilesLargerThan = min(self.skipFilesLargerThan, presetRules.skipFilesLargerThan)

        // Merge locations (unique)
        self.includeLocations = Array(Set(self.includeLocations + presetRules.includeLocations)).sorted()
        self.excludeLocations = Array(Set(self.excludeLocations + presetRules.excludeLocations)).sorted()

        // Merge app caches (unique)
        self.appCachesToClean = Array(Set(self.appCachesToClean + presetRules.appCachesToClean)).sorted()

        // Set active preset
        self.activePreset = preset
        if !self.appliedPresets.contains(preset) {
            self.appliedPresets.append(preset)
        }
    }
}