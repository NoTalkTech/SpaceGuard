import Foundation

class RuleManager {
    private let riskAnalyzer = RiskAnalyzer()

    /// Validates rules and returns any conflicts found
    func validateRules(_ rules: CleanupRules) -> (isValid: Bool, conflicts: [RuleConflict]) {
        let conflicts = rules.detectConflicts()
        return (conflicts.isEmpty, conflicts)
    }

    /// Applies rule priority management and resolves conflicts
    func applyRulePriorityManagement(_ rules: inout CleanupRules) {
        // Auto-resolve conflicts before processing
        rules.resolveConflicts()

        // Apply additional priority logic

        // Priority 1: Custom risk overrides take highest precedence
        // Ensure custom overrides are applied before any other rules
        // This is already handled in RiskAnalyzer.classifyRisk()

        // Priority 2: System file protection
        // Ensure system paths are always excluded unless explicitly included
        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/Library/Developer"]
        for systemPath in systemPaths {
            if !rules.excludeLocations.contains(where: { $0 == systemPath }) {
                // Add system paths to exclude list if not already present
                rules.excludeLocations.append(systemPath)
            }
        }

        // Priority 3: User home directory protection
        let home = NSHomeDirectory()
        let userProtectedPaths = [
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Movies",
            "\(home)/Music"
        ]

        for userPath in userProtectedPaths {
            if !rules.excludeLocations.contains(where: { $0 == userPath }) {
                rules.excludeLocations.append(userPath)
            }
        }

        // Priority 4: Ensure minimum age thresholds are reasonable
        rules.deleteDownloadsOlderThanDays = max(1, rules.deleteDownloadsOlderThanDays)
        rules.deleteLogsOlderThanDays = max(0, rules.deleteLogsOlderThanDays)
        rules.deleteCacheOlderThanDays = max(0, rules.deleteCacheOlderThanDays)

        // Priority 5: Size thresholds validation
        rules.minimumFileSizeToConsider = max(0, rules.minimumFileSizeToConsider)
        rules.skipFilesLargerThan = max(rules.minimumFileSizeToConsider * 10, rules.skipFilesLargerThan)
    }

    /// Dynamically adjusts rules based on file characteristics
    func applyDynamicRules(_ file: FileItem, _ rules: CleanupRules) -> CleanupRules {
        var adjustedRules = rules

        // Dynamic adjustments based on file characteristics
        // 1. Adjust age thresholds for large files
        if file.size > 500 * 1024 * 1024 { // 500 MB
            // Be more conservative with large files
            let currentThreshold = adjustedRules.deleteDownloadsOlderThanDays
            if file.path.contains("/Downloads/") && currentThreshold < 30 {
                adjustedRules.deleteDownloadsOlderThanDays = max(currentThreshold, 30)
            }
        }

        // 2. Adjust for system files
        let path = file.path
        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private"]
        if systemPaths.contains(where: { path.hasPrefix($0) }) {
            // Always treat system files as high risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .high
                ))
            }
        }

        // 3. Adjust for application bundles and executables
        if file.path.hasSuffix(".app") || file.path.contains(".app/") || file.path.hasSuffix(".dmg") || file.path.hasSuffix(".pkg") {
            // Application bundles and installers should be high risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .high
                ))
            }
        }

        // 4. Adjust for very small files (likely temporary/cache)
        if file.size < 1024 * 1024 { // 1 MB
            // Small files can be treated as lower risk if they're in cache/temp locations
            if file.path.contains("/Caches/") || file.path.contains("/tmp/") || file.path.contains("/var/tmp/") {
                if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                    adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                        path: path,
                        riskLevel: .low
                    ))
                }
            }
        }

        // 5. Adjust for file age - very old files in certain locations
        let ageInDays = Calendar.current.dateComponents([.day], from: file.modified, to: Date()).day ?? 0
        if ageInDays > 365 { // Older than 1 year
            if file.path.contains("/Downloads/") || file.path.contains("/Documents/") {
                // Very old user files might be less important
                if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) && rules.getCustomRiskOverride(for: path) == nil {
                    adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                        path: path,
                        riskLevel: .medium
                    ))
                }
            }
        }

        // 6. Adjust for specific file extensions
        let fileExtension = (file.path as NSString).pathExtension.lowercased()
        let highRiskExtensions = ["kext", "component", "plugin", "framework", "bundle"]
        let lowRiskExtensions = ["log", "cache", "tmp", "temp", "db", "db-wal", "db-shm"]

        if highRiskExtensions.contains(fileExtension) {
            // System extensions and plugins are high risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .high
                ))
            }
        } else if lowRiskExtensions.contains(fileExtension) {
            // Cache and log files are lower risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) && rules.getCustomRiskOverride(for: path) == nil {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .low
                ))
            }
        }

        return adjustedRules
    }

    /// Combines multiple rule strategies for better decision making
    func combineRuleStrategies(_ file: FileItem, _ rules: CleanupRules) -> (shouldDelete: Bool, confidence: Double) {
        let assessment = riskAnalyzer.assessRisk(for: file, rules: rules)
        var confidence = 100.0 - assessment.riskScore // Higher confidence for lower risk

        // Apply rule combinations
        var shouldDelete = false
        var combinationCount = 0

        // Combination 1: Age + Location + Risk Level
        if assessment.riskLevel == .low {
            // Low risk files: consider age and location
            let ageInDays = Calendar.current.dateComponents([.day], from: file.modified, to: Date()).day ?? 0

            if file.path.contains("/Caches/") && ageInDays > 7 {
                shouldDelete = true
                confidence = min(confidence + 10.0, 95.0)
                combinationCount += 1
            } else if file.path.contains("/tmp/") && ageInDays > 1 {
                shouldDelete = true
                confidence = min(confidence + 15.0, 95.0)
                combinationCount += 1
            }
        }

        // Combination 2: Size + File Type + Custom Override
        let customOverride = rules.getCustomRiskOverride(for: file.path)
        if customOverride == .low && file.size < 10 * 1024 * 1024 { // 10 MB
            shouldDelete = true
            confidence = min(confidence + 20.0, 95.0)
            combinationCount += 1
        }

        // Combination 3: File Extension + Age + Location
        let fileExtension = (file.path as NSString).pathExtension.lowercased()
        let ageInDays = Calendar.current.dateComponents([.day], from: file.modified, to: Date()).day ?? 0

        if ["log", "cache", "tmp", "temp"].contains(fileExtension) && ageInDays > 30 {
            // Old log/cache files in user directories
            if file.path.contains(NSHomeDirectory()) && !file.path.contains("/Library/Application Support/") {
                shouldDelete = true
                confidence = min(confidence + 25.0, 95.0)
                combinationCount += 1
            }
        }

        // Combination 4: Large files in download directory with custom risk override
        if file.path.contains("/Downloads/") && file.size > 100 * 1024 * 1024 { // 100 MB
            if let customRisk = rules.getCustomRiskOverride(for: file.path) {
                if customRisk == .medium && ageInDays > 60 {
                    shouldDelete = true
                    confidence = min(confidence + 30.0, 95.0)
                    combinationCount += 1
                }
            } else if ageInDays > 180 { // 6 months old large downloads
                shouldDelete = true
                confidence = min(confidence + 15.0, 95.0)
                combinationCount += 1
            }
        }

        // Combination 5: File in excluded location but with low risk assessment
        let isInExcludedLocation = rules.excludeLocations.contains { file.path.hasPrefix($0) }
        if isInExcludedLocation && assessment.riskLevel == .low && assessment.riskScore < 20 {
            // File is in excluded location but has very low risk score
            // This might indicate a false positive - upgrade to confirm
            shouldDelete = false
            confidence = max(confidence - 10.0, 5.0) // Reduce confidence
            combinationCount += 1
        }

        // Combination 6: App-specific cache files
        if rules.isAppCache(file.path) && ageInDays > 14 {
            // App cache files older than 2 weeks
            shouldDelete = true
            confidence = min(confidence + 35.0, 95.0)
            combinationCount += 1
        }

        // Adjust final confidence based on number of applicable combinations
        if combinationCount > 1 {
            // Multiple combinations agree - increase confidence
            confidence = min(confidence + Double(combinationCount * 5), 95.0)
        } else if combinationCount == 0 {
            // No specific combinations apply - use base confidence but reduce slightly
            confidence = max(confidence - 5.0, 5.0)
        }

        return (shouldDelete, confidence)
    }
}
