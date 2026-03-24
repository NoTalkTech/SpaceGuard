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
    }

    static func load() -> CleanupRules {
        let defaults = UserDefaults.standard

        var rules = CleanupRules()

        if defaults.object(forKey: "autoCleanLowRisk") != nil {
            rules.autoCleanLowRisk = defaults.bool(forKey: "autoCleanLowRisk")
        }

        if defaults.object(forKey: "confirmMediumRisk") != nil {
            rules.confirmMediumRisk = defaults.bool(forKey: "confirmMediumRisk")
        }

        if defaults.object(forKey: "neverDeleteHighRisk") != nil {
            rules.neverDeleteHighRisk = defaults.bool(forKey: "neverDeleteHighRisk")
        }

        if defaults.object(forKey: "deleteDownloadsOlderThanDays") != nil {
            rules.deleteDownloadsOlderThanDays = defaults.integer(forKey: "deleteDownloadsOlderThanDays")
        }

        if defaults.object(forKey: "deleteLogsOlderThanDays") != nil {
            rules.deleteLogsOlderThanDays = defaults.integer(forKey: "deleteLogsOlderThanDays")
        }

        if defaults.object(forKey: "deleteCacheOlderThanDays") != nil {
            rules.deleteCacheOlderThanDays = defaults.integer(forKey: "deleteCacheOlderThanDays")
        }

        if let savedIncludes = defaults.stringArray(forKey: "includeLocations") {
            rules.includeLocations = savedIncludes
        }

        if let savedExcludes = defaults.stringArray(forKey: "excludeLocations") {
            rules.excludeLocations = savedExcludes
        }

        if let savedAppCaches = defaults.stringArray(forKey: "appCachesToClean") {
            rules.appCachesToClean = savedAppCaches
        }

        // Load advanced rules
        if let fileTypeRulesData = defaults.data(forKey: "fileTypeRules"),
           let decoded = try? JSONDecoder().decode(FileTypeRules.self, from: fileTypeRulesData) {
            rules.fileTypeRules = decoded
        }

        if let customOverridesData = defaults.data(forKey: "customRiskOverrides"),
           let decoded = try? JSONDecoder().decode([CustomRiskOverride].self, from: customOverridesData) {
            rules.customRiskOverrides = decoded
        }

        if let exclusionPatterns = defaults.stringArray(forKey: "exclusionPatterns") {
            rules.exclusionPatterns = exclusionPatterns
        }

        if let scheduledCleanupData = defaults.data(forKey: "scheduledCleanup"),
           let decoded = try? JSONDecoder().decode(ScheduledCleanup.self, from: scheduledCleanupData) {
            rules.scheduledCleanup = decoded
        }

        return rules
    }

    func save() {
        let defaults = UserDefaults.standard

        defaults.set(autoCleanLowRisk, forKey: "autoCleanLowRisk")
        defaults.set(confirmMediumRisk, forKey: "confirmMediumRisk")
        defaults.set(neverDeleteHighRisk, forKey: "neverDeleteHighRisk")
        defaults.set(deleteDownloadsOlderThanDays, forKey: "deleteDownloadsOlderThanDays")
        defaults.set(deleteLogsOlderThanDays, forKey: "deleteLogsOlderThanDays")
        defaults.set(deleteCacheOlderThanDays, forKey: "deleteCacheOlderThanDays")
        defaults.set(includeLocations, forKey: "includeLocations")
        defaults.set(excludeLocations, forKey: "excludeLocations")
        defaults.set(appCachesToClean, forKey: "appCachesToClean")
        defaults.set(exclusionPatterns, forKey: "exclusionPatterns")

        // Save advanced rules as JSON data
        if let fileTypeRulesData = try? JSONEncoder().encode(fileTypeRules) {
            defaults.set(fileTypeRulesData, forKey: "fileTypeRules")
        }

        if let customOverridesData = try? JSONEncoder().encode(customRiskOverrides) {
            defaults.set(customOverridesData, forKey: "customRiskOverrides")
        }

        if let scheduledCleanup = scheduledCleanup,
           let scheduledData = try? JSONEncoder().encode(scheduledCleanup) {
            defaults.set(scheduledData, forKey: "scheduledCleanup")
        }
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
}

// MARK: - Rule Conflict Structures

enum RuleConflictType: String, Codable {
    case pathInclusionExclusion = "Path inclusion/exclusion conflict"
    case fileTypeRule = "File type rule conflict"
    case customRiskOverride = "Custom risk override conflict"
    case ageThreshold = "Age threshold conflict"
    case sizeThreshold = "Size threshold conflict"
}

enum ConflictSeverity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct RuleConflict: Identifiable, Codable {
    let id = UUID()
    let type: RuleConflictType
    let description: String
    let severity: ConflictSeverity

    enum CodingKeys: String, CodingKey {
        case type, description, severity
        // id is excluded from coding because it's auto-generated
    }
}

// MARK: - Advanced Rule Structures

struct FileTypeRules: Codable {
    var whitelistedExtensions: [String] = [] // Empty means all allowed
    var blacklistedExtensions: [String] = [".app", ".dmg", ".pkg", ".kext", ".component"]

    static let `default` = FileTypeRules()
}

struct CustomRiskOverride: Codable, Identifiable {
    let id = UUID()
    var path: String
    var riskLevel: RiskLevel

    enum CodingKeys: String, CodingKey {
        case path, riskLevel
    }
}

struct ScheduledCleanup: Codable {
    var enabled: Bool = false
    var frequency: CleanupFrequency = .weekly
    var timeOfDay: Date = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date()) ?? Date() // 2 AM
    var lastRun: Date?

    enum CleanupFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var timeInterval: TimeInterval {
            switch self {
            case .daily: return 86400 // 24 hours
            case .weekly: return 604800 // 7 days
            case .monthly: return 2592000 // 30 days
            }
        }
    }
}