import Foundation

class RiskAnalyzer {
    private let fileManager = FileManager.default

    func analyzeFiles(_ files: [FileItem]) -> [FileItem] {
        files.map { file in
            let riskLevel = classifyRisk(for: file.url)
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

    func classifyRisk(for url: URL) -> RiskLevel {
        let path = url.path

        // High risk: System files and critical user data
        if isSystemFile(path) || isApplicationBundle(path) || isCriticalUserFile(path) {
            return .high
        }

        // Medium risk: User data that might be important
        if isUserDocument(path) || isRecentDownload(path) || isLogFile(path) {
            return .medium
        }

        // Low risk: Cache and temporary files
        if isCacheFile(path) || isTempFile(path) || isTrashFile(path) {
            return .low
        }

        // Default to medium for unknown files
        return .medium
    }

    func getRiskReason(for url: URL, riskLevel: RiskLevel) -> String {
        let path = url.path

        switch riskLevel {
        case .high:
            if isSystemFile(path) {
                return "System file"
            } else if isApplicationBundle(path) {
                return "Application bundle"
            } else if isCriticalUserFile(path) {
                return "Critical user file"
            }

        case .medium:
            if isUserDocument(path) {
                return "User document"
            } else if isRecentDownload(path) {
                return "Recent download"
            } else if isLogFile(path) {
                return "Log file"
            }

        case .low:
            if isCacheFile(path) {
                return "Cache file"
            } else if isTempFile(path) {
                return "Temporary file"
            } else if isTrashFile(path) {
                return "Trash content"
            }
        }

        return "Unknown file type"
    }

    // MARK: - Classification Helpers

    private func isSystemFile(_ path: String) -> Bool {
        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/Library", "/Applications/Utilities"]
        return systemPaths.contains { path.hasPrefix($0) }
    }

    private func isApplicationBundle(_ path: String) -> Bool {
        return path.hasSuffix(".app") || path.contains(".app/")
    }

    private func isCriticalUserFile(_ path: String) -> Bool {
        let home = NSHomeDirectory()
        let criticalPaths = [
            "\(home)/Library/Application Support",
            "\(home)/Library/Preferences",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Movies",
            "\(home)/Music"
        ]

        return criticalPaths.contains { path.hasPrefix($0) }
    }

    private func isUserDocument(_ path: String) -> Bool {
        let home = NSHomeDirectory()
        let documentPaths = [
            "\(home)/Downloads",
            "\(home)/Public",
            "\(home)/Sites"
        ]

        return documentPaths.contains { path.hasPrefix($0) } && !isRecentDownload(path)
    }

    private func isRecentDownload(_ path: String) -> Bool {
        let home = NSHomeDirectory()
        guard path.hasPrefix("\(home)/Downloads/") else {
            return false
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let modDate = attributes[.modificationDate] as? Date {
                let daysOld = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
                return daysOld < 30 // Less than 30 days old
            }
        } catch {
            return false
        }

        return false
    }

    private func isLogFile(_ path: String) -> Bool {
        return path.contains("Logs") || path.contains(".log") || path.hasSuffix(".log")
    }

    private func isCacheFile(_ path: String) -> Bool {
        return path.contains("Caches") || path.contains("Cache.") ||
               path.contains("/tmp/") || path.contains(".cache")
    }

    private func isTempFile(_ path: String) -> Bool {
        return path.contains("/tmp/") || path.contains("/var/tmp/") ||
               path.hasPrefix("/private/tmp/") || path.hasPrefix("/private/var/tmp/")
    }

    private func isTrashFile(_ path: String) -> Bool {
        return path.contains(".Trash") || path.contains("Trash") || path.contains("废纸篓")
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
}