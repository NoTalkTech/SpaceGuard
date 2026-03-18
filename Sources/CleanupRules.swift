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