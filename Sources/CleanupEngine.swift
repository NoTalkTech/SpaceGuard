import Foundation

class CleanupEngine {
    private let fileManager = FileManager.default
    private var isCleaning = false
    private var cancellationToken: Bool = false

    struct CleanupResult {
        let filesDeleted: Int
        let spaceFreed: Int64
        let duration: TimeInterval
        let errors: [CleanupError]
    }

    struct CleanupError: Error {
        let filePath: String
        let error: Swift.Error
    }

    func cleanupFiles(
        _ files: [FileItem],
        rules: CleanupRules,
        progress: @escaping (Int, Int, Int64) -> Void,
        confirmAction: ((FileItem) async -> Bool)? = nil
    ) async -> CleanupResult {
        guard !isCleaning else {
            return CleanupResult(filesDeleted: 0, spaceFreed: 0, duration: 0, errors: [])
        }

        isCleaning = true
        cancellationToken = false
        let startTime = Date()

        defer {
            isCleaning = false
            cancellationToken = false
        }

        var filesDeleted = 0
        var spaceFreed: Int64 = 0
        var errors: [CleanupError] = []

        let totalFiles = files.count

        for (index, file) in files.enumerated() {
            if cancellationToken {
                break
            }

            // Check rules and get deletion decision
            let deletionDecision = shouldDeleteFile(file, rules: rules)

            switch deletionDecision {
            case .skip:
                continue
            case .confirm:
                // Ask for confirmation if callback provided
                if let confirmAction = confirmAction {
                    let shouldDelete = await confirmAction(file)
                    if !shouldDelete {
                        continue
                    }
                } else {
                    // No confirmation callback, skip the file
                    continue
                }
            case .delete:
                break // Proceed with deletion
            }

            do {
                try deleteFile(file)
                filesDeleted += 1
                spaceFreed += file.size

                // Update progress
                progress(index + 1, totalFiles, spaceFreed)

                // Small delay to avoid overwhelming the system
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            } catch {
                errors.append(CleanupError(filePath: file.path, error: error))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return CleanupResult(
            filesDeleted: filesDeleted,
            spaceFreed: spaceFreed,
            duration: duration,
            errors: errors
        )
    }

    enum DeletionDecision {
        case skip
        case confirm
        case delete
    }

    private func shouldDeleteFile(_ file: FileItem, rules: CleanupRules) -> DeletionDecision {
        // Check risk level rules
        switch file.riskLevel {
        case .high:
            return rules.neverDeleteHighRisk ? .skip : .confirm
        case .medium:
            return rules.confirmMediumRisk ? .confirm : .skip
        case .low:
            return rules.autoCleanLowRisk ? .delete : .skip
        }
    }

    private func deleteFile(_ file: FileItem) throws {
        let url = file.url

        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        // Try to move to trash first (safer)
        if #available(macOS 10.8, *) {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
            print("Moved to trash: \(url.path)")
        } else {
            // Fallback: permanent delete
            try fileManager.removeItem(at: url)
            print("Permanently deleted: \(url.path)")
        }
    }

    func cancelCleanup() {
        cancellationToken = true
    }

    func calculatePotentialSavings(_ files: [FileItem], rules: CleanupRules) -> (lowRisk: Int64, mediumRisk: Int64, highRisk: Int64) {
        var lowRiskSavings: Int64 = 0
        var mediumRiskSavings: Int64 = 0
        var highRiskSavings: Int64 = 0

        for file in files {
            if !rules.shouldIncludeFile(at: file.path) {
                continue
            }

            switch file.riskLevel {
            case .low:
                if rules.autoCleanLowRisk {
                    lowRiskSavings += file.size
                }
            case .medium:
                if rules.confirmMediumRisk {
                    mediumRiskSavings += file.size
                }
            case .high:
                if !rules.neverDeleteHighRisk {
                    highRiskSavings += file.size
                }
            }
        }

        return (lowRiskSavings, mediumRiskSavings, highRiskSavings)
    }

    func quickCleanup(rules: CleanupRules, progress: @escaping (Int, Int, Int64) -> Void, confirmAction: ((FileItem) async -> Bool)? = nil) async -> CleanupResult {
        // Identify common cache locations
        let cachePaths = [
            NSHomeDirectory() + "/Library/Caches",
            "/Library/Caches",
            "/var/tmp",
            "/tmp"
        ]

        var allFiles: [FileItem] = []

        for path in cachePaths {
            guard fileManager.fileExists(atPath: path) else {
                continue
            }

            let scanner = DiskScanner()
            do {
                let result = try await scanner.scanDirectory(at: path) { _, _ in }
                let analyzer = RiskAnalyzer()
                let analyzedFiles = analyzer.analyzeFiles(result.files, rules: rules)
                allFiles.append(contentsOf: analyzedFiles)
            } catch {
                print("Error scanning \(path): \(error)")
            }
        }

        // Filter for low-risk files only
        let lowRiskFiles = allFiles.filter { $0.riskLevel == .low }

        return await cleanupFiles(lowRiskFiles, rules: rules, progress: progress, confirmAction: confirmAction)
    }
}