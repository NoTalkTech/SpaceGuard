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
    }

    func shouldIncludeFile(at path: String) -> Bool {
        // Check if in exclude locations
        for exclude in excludeLocations {
            if path.hasPrefix(exclude) {
                return false
            }
        }

        // Check if in include locations
        for include in includeLocations {
            if path.hasPrefix(include) {
                return true
            }
        }

        // Default: include files from home directory (user files)
        return path.hasPrefix(NSHomeDirectory())
    }

    func isAppCache(_ path: String) -> Bool {
        for appCache in appCachesToClean {
            if path.contains(appCache) {
                return true
            }
        }
        return false
    }
}