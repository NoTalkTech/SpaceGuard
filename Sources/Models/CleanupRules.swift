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
