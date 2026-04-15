import Foundation

class RulesPersistenceService: RulesPersisting {

    func loadRules() -> CleanupRules {
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

        if defaults.object(forKey: "minimumFileSizeToConsider") != nil {
            rules.minimumFileSizeToConsider = Int64(defaults.integer(forKey: "minimumFileSizeToConsider"))
        }

        if defaults.object(forKey: "skipFilesLargerThan") != nil {
            rules.skipFilesLargerThan = Int64(defaults.integer(forKey: "skipFilesLargerThan"))
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

    func saveRules(_ rules: CleanupRules) {
        let defaults = UserDefaults.standard

        defaults.set(rules.autoCleanLowRisk, forKey: "autoCleanLowRisk")
        defaults.set(rules.confirmMediumRisk, forKey: "confirmMediumRisk")
        defaults.set(rules.neverDeleteHighRisk, forKey: "neverDeleteHighRisk")
        defaults.set(rules.deleteDownloadsOlderThanDays, forKey: "deleteDownloadsOlderThanDays")
        defaults.set(rules.deleteLogsOlderThanDays, forKey: "deleteLogsOlderThanDays")
        defaults.set(rules.deleteCacheOlderThanDays, forKey: "deleteCacheOlderThanDays")
        defaults.set(rules.minimumFileSizeToConsider, forKey: "minimumFileSizeToConsider")
        defaults.set(rules.skipFilesLargerThan, forKey: "skipFilesLargerThan")
        defaults.set(rules.includeLocations, forKey: "includeLocations")
        defaults.set(rules.excludeLocations, forKey: "excludeLocations")
        defaults.set(rules.appCachesToClean, forKey: "appCachesToClean")
        defaults.set(rules.exclusionPatterns, forKey: "exclusionPatterns")

        // Save advanced rules as JSON data
        if let fileTypeRulesData = try? JSONEncoder().encode(rules.fileTypeRules) {
            defaults.set(fileTypeRulesData, forKey: "fileTypeRules")
        }

        if let customOverridesData = try? JSONEncoder().encode(rules.customRiskOverrides) {
            defaults.set(customOverridesData, forKey: "customRiskOverrides")
        }

        if let scheduledCleanup = rules.scheduledCleanup,
           let scheduledData = try? JSONEncoder().encode(scheduledCleanup) {
            defaults.set(scheduledData, forKey: "scheduledCleanup")
        }

        defaults.removeObject(forKey: "activePreset")
        defaults.removeObject(forKey: "appliedPresets")
    }
}
