import Foundation

// MARK: - Risk Assessment Data Structures

struct RiskFactor: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let weight: Double
    let score: Double
    let maxScore: Double

    enum CodingKeys: String, CodingKey {
        case name, description, weight, score, maxScore
        // id is excluded from coding because it's auto-generated
    }
}

struct RiskAssessment: Codable {
    let riskLevel: RiskLevel
    let riskScore: Double // 0-100
    let primaryReason: String
    let factors: [RiskFactor]
    let recommendedAction: String

    init(riskLevel: RiskLevel, riskScore: Double, primaryReason: String, factors: [RiskFactor]) {
        self.riskLevel = riskLevel
        self.riskScore = riskScore
        self.primaryReason = primaryReason
        self.factors = factors

        // Determine recommended action based on risk level and score
        switch riskLevel {
        case .high:
            self.recommendedAction = "Do not delete"
        case .medium:
            if riskScore > 70 {
                self.recommendedAction = "Confirm before deleting"
            } else {
                self.recommendedAction = "Consider for deletion"
            }
        case .low:
            if riskScore > 30 {
                self.recommendedAction = "Confirm before deleting"
            } else {
                self.recommendedAction = "Safe to delete automatically"
            }
        }
    }
}

// MARK: - Risk Analyzer

class RiskAnalyzer {
    private let classifier = FileClassifier()

    func analyzeFiles(_ files: [FileItem], rules: CleanupRules? = nil) -> [FileItem] {
        files.map { file in
            let riskLevel = classifyRisk(for: file.url, rules: rules)
            let reason = getRiskReason(for: file.url, riskLevel: riskLevel)

            return FileItem(
                url: file.url,
                size: file.size,
                created: file.created,
                modified: file.modified,
                riskLevel: riskLevel,
                reason: reason
            )
        }
    }

    /// Assess risk for a file using weighted multi-factor analysis
    func assessRisk(for file: FileItem, rules: CleanupRules) -> RiskAssessment {
        var factors: [RiskFactor] = []

        // 1. Path-based classification (highest weight)
        let pathFactor = assessPathRisk(file.url.path, rules: rules)
        factors.append(pathFactor)

        // 2. Age-based risk
        let ageFactor = assessAgeRisk(file.modified, file.path, rules: rules)
        factors.append(ageFactor)

        // 3. Size-based risk
        let sizeFactor = assessSizeRisk(file.size, rules: rules)
        factors.append(sizeFactor)

        // 4. File type risk
        let typeFactor = assessFileTypeRisk(file.url.path, rules: rules)
        factors.append(typeFactor)

        // 5. Location inclusion/exclusion
        let locationFactor = assessLocationRisk(file.path, rules: rules)
        factors.append(locationFactor)

        // Calculate total weighted score
        let totalWeight = factors.reduce(0) { $0 + $1.weight }
        let weightedScore = factors.reduce(0) { $0 + ($1.score * $1.weight) }
        let normalizedScore = totalWeight > 0 ? weightedScore / totalWeight : 0

        // Determine risk level based on score
        let riskLevel: RiskLevel
        if normalizedScore >= 70 {
            riskLevel = .high
        } else if normalizedScore >= 30 {
            riskLevel = .medium
        } else {
            riskLevel = .low
        }

        // Get primary reason (factor with highest contribution)
        let primaryFactor = factors.max(by: { ($0.score * $0.weight) < ($1.score * $1.weight) })
        let primaryReason = primaryFactor?.description ?? "Unknown risk"

        return RiskAssessment(
            riskLevel: riskLevel,
            riskScore: normalizedScore,
            primaryReason: primaryReason,
            factors: factors
        )
    }

    func classifyRisk(for url: URL, rules: CleanupRules? = nil) -> RiskLevel {
        let path = url.path

        // Check custom risk override first
        if let rules = rules, let customRisk = rules.getCustomRiskOverride(for: path) {
            return customRisk
        }

        // Low risk: Cache and temporary files (safest to delete)
        if classifier.isCacheFile(path) || classifier.isTempFile(path) || classifier.isTrashFile(path) {
            return .low
        }

        // Medium risk: User data that might be important
        if classifier.isUserDocument(path) || classifier.isRecentDownload(path) || classifier.isLogFile(path) {
            return .medium
        }

        // High risk: System files and critical user data
        if classifier.isSystemFile(path) || classifier.isApplicationBundle(path) || classifier.isCriticalUserFile(path) {
            return .high
        }

        // Default to medium for unknown files
        return .medium
    }

    func getRiskReason(for url: URL, riskLevel: RiskLevel) -> String {
        let path = url.path

        switch riskLevel {
        case .high:
            if classifier.isSystemFile(path) {
                return "System file"
            } else if classifier.isApplicationBundle(path) {
                return "Application bundle"
            } else if classifier.isCriticalUserFile(path) {
                return "Critical user file"
            }

        case .medium:
            if classifier.isUserDocument(path) {
                return "User document"
            } else if classifier.isRecentDownload(path) {
                return "Recent download"
            } else if classifier.isLogFile(path) {
                return "Log file"
            }

        case .low:
            if classifier.isTempFile(path) {
                return "Temporary file"
            } else if classifier.isCacheFile(path) {
                return "Cache file"
            } else if classifier.isTrashFile(path) {
                return "Trash content"
            }
        }

        return "Unknown file type"
    }

    // MARK: - Statistics

    func calculateRiskStatistics(_ files: [FileItem]) -> [RiskLevel: (count: Int, size: Int64)] {
        var stats: [RiskLevel: (count: Int, size: Int64)] = [
            .low: (0, 0),
            .medium: (0, 0),
            .high: (0, 0)
        ]

        for file in files {
            var current = stats[file.riskLevel] ?? (0, 0)
            current.count += 1
            current.size += file.size
            stats[file.riskLevel] = current
        }

        return stats
    }

    // MARK: - Risk Assessment Helpers

    private func assessPathRisk(_ path: String, rules: CleanupRules) -> RiskFactor {
        var score: Double = 50.0 // Default medium risk
        var description = "Standard file path"

        // Check custom risk override first
        if let customRisk = rules.getCustomRiskOverride(for: path) {
            switch customRisk {
            case .high:
                score = 90.0
                description = "Custom override: High risk"
            case .medium:
                score = 60.0
                description = "Custom override: Medium risk"
            case .low:
                score = 20.0
                description = "Custom override: Low risk"
            }
        } else if classifier.isSystemFile(path) || classifier.isApplicationBundle(path) || classifier.isCriticalUserFile(path) {
            score = 90.0
            description = "System or critical file"
        } else if classifier.isUserDocument(path) || classifier.isLogFile(path) {
            score = 70.0
            description = "User document or log file"
        } else if classifier.isRecentDownload(path) {
            score = 65.0
            description = "Recent download"
        } else if classifier.isCacheFile(path) || classifier.isTempFile(path) || classifier.isTrashFile(path) {
            score = 20.0
            description = "Cache or temporary file"
        }

        return RiskFactor(
            name: "Path Classification",
            description: description,
            weight: 0.4, // 40% weight - most important factor
            score: score,
            maxScore: 100.0
        )
    }

    private func assessAgeRisk(_ modifiedDate: Date, _ path: String, rules: CleanupRules) -> RiskFactor {
        let now = Date()
        let daysOld = Calendar.current.dateComponents([.day], from: modifiedDate, to: now).day ?? 0
        var score: Double = 50.0
        var description = "Standard age (\(daysOld) days old)"

        // Apply age-based rules
        if path.contains("/Downloads/") && daysOld > rules.deleteDownloadsOlderThanDays {
            score = 20.0 // Old download - lower risk (safer to delete)
            description = "Old download (\(daysOld) days, threshold: \(rules.deleteDownloadsOlderThanDays) days)"
        } else if classifier.isLogFile(path) && daysOld > rules.deleteLogsOlderThanDays {
            score = 25.0 // Old log file
            description = "Old log file (\(daysOld) days, threshold: \(rules.deleteLogsOlderThanDays) days)"
        } else if classifier.isCacheFile(path) && daysOld > rules.deleteCacheOlderThanDays {
            score = 15.0 // Old cache file
            description = "Old cache file (\(daysOld) days, threshold: \(rules.deleteCacheOlderThanDays) days)"
        } else if daysOld < 7 {
            score = 80.0 // Very recent file - higher risk
            description = "Very recent file (\(daysOld) days old)"
        } else if daysOld < 30 {
            score = 65.0 // Recent file
            description = "Recent file (\(daysOld) days old)"
        }

        return RiskFactor(
            name: "File Age",
            description: description,
            weight: 0.25, // 25% weight
            score: score,
            maxScore: 100.0
        )
    }

    private func assessSizeRisk(_ size: Int64, rules: CleanupRules) -> RiskFactor {
        var score: Double = 50.0
        var description = "Medium size file"

        let mbSize = Double(size) / (1024 * 1024)

        if size < rules.minimumFileSizeToConsider {
            score = 85.0 // Small files - higher risk (often safe to delete)
            description = "Small file (\(String(format: "%.1f", mbSize)) MB, below threshold)"
        } else if size > rules.skipFilesLargerThan {
            score = 30.0 // Very large files - lower risk (be careful)
            description = "Very large file (\(String(format: "%.1f", mbSize)) MB, above threshold)"
        } else if size > 500 * 1024 * 1024 { // 500 MB
            score = 40.0 // Large file
            description = "Large file (\(String(format: "%.1f", mbSize)) MB)"
        }

        return RiskFactor(
            name: "File Size",
            description: description,
            weight: 0.15, // 15% weight
            score: score,
            maxScore: 100.0
        )
    }

    private func assessFileTypeRisk(_ path: String, rules: CleanupRules) -> RiskFactor {
        let fileExtension = (path as NSString).pathExtension.lowercased()
        var score: Double = 50.0
        var description = "Standard file type"

        // Check blacklist
        if rules.fileTypeRules.blacklistedExtensions.contains(fileExtension) {
            score = 85.0 // Blacklisted extension - higher risk (safer to delete?)
            description = "Blacklisted file type (.\(fileExtension))"
        } else if !rules.fileTypeRules.whitelistedExtensions.isEmpty &&
                  !rules.fileTypeRules.whitelistedExtensions.contains(fileExtension) {
            score = 75.0 // Not in whitelist
            description = "File type not in whitelist (.\(fileExtension))"
        } else if fileExtension.isEmpty {
            score = 60.0 // No extension - could be important
            description = "File with no extension"
        } else if ["app", "dmg", "pkg", "kext", "component"].contains(fileExtension) {
            score = 90.0 // System/application files
            description = "System/application file (.\(fileExtension))"
        } else if ["log", "cache", "tmp", "temp"].contains(fileExtension) {
            score = 20.0 // Temporary/log files
            description = "Temporary/log file (.\(fileExtension))"
        }

        return RiskFactor(
            name: "File Type",
            description: description,
            weight: 0.1, // 10% weight
            score: score,
            maxScore: 100.0
        )
    }

    private func assessLocationRisk(_ path: String, rules: CleanupRules) -> RiskFactor {
        var score: Double = 50.0
        var description = "Standard location"

        // Check exclude locations
        for exclude in rules.excludeLocations {
            if path.hasPrefix(exclude) {
                score = 90.0 // In excluded location - higher risk (do not delete)
                description = "Located in excluded directory"
                return RiskFactor(
                    name: "Location",
                    description: description,
                    weight: 0.05, // 5% weight
                    score: score,
                    maxScore: 100.0
                )
            }
        }

        // Check include locations
        var isIncluded = false
        for include in rules.includeLocations {
            if path.hasPrefix(include) {
                isIncluded = true
                break
            }
        }

        if isIncluded {
            score = 30.0 // In included location - lower risk (safer to delete)
            description = "Located in included cleanup directory"
        } else if path.hasPrefix(NSHomeDirectory()) {
            score = 60.0 // User home directory but not specifically included
            description = "User file not in cleanup directories"
        } else {
            score = 70.0 // Outside home directory
            description = "File outside user home directory"
        }

        // Check app-specific caches
        if rules.isAppCache(path) {
            score = min(score, 25.0) // App cache - even lower risk
            description = "Application cache file"
        }

        return RiskFactor(
            name: "Location",
            description: description,
            weight: 0.05, // 5% weight
            score: score,
            maxScore: 100.0
        )
    }
}