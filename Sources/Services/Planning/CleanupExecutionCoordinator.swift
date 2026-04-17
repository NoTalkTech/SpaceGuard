import Foundation

struct CleanupExecutionCoordinator: CleanupExecutionCoordinating {
    private let cleanupEngine: CleanupEngine
    private let fileManager: FileManager

    init(cleanupEngine: CleanupEngine = CleanupEngine(), fileManager: FileManager = .default) {
        self.cleanupEngine = cleanupEngine
        self.fileManager = fileManager
    }

    func execute(
        items: [CleanupPlanItem],
        rules: CleanupRules,
        update: @escaping (CleanupExecutionUpdate) -> Void
    ) async -> CleanupExecutionSummary {
        let executableItems = items.filter { $0.actionType != .suggestOnly }
        let startedAt = Date()

        var executedItems: [CleanupPlanItem] = []
        var filesDeleted = 0
        var spaceFreed: Int64 = 0
        var errors: [CleanupEngine.CleanupError] = []

        for (index, item) in executableItems.enumerated() {
            update(
                CleanupExecutionUpdate(
                    currentItemTitle: item.title,
                    currentItemIndex: index,
                    totalItems: executableItems.count,
                    overallProgress: Double(index) / Double(max(executableItems.count, 1)),
                    totalSpaceFreed: spaceFreed
                )
            )

            let result: CleanupEngine.CleanupResult

            switch item.actionType {
            case .scenarioExecution:
                guard let scenario = item.backingScenario else { continue }
                result = await cleanupEngine.executeScenarioCleanup(scenario, rules: rules) { current, total, freed in
                    let itemProgress = total > 0 ? Double(current) / Double(total) : 0
                    let overallProgress = (Double(index) + itemProgress) / Double(max(executableItems.count, 1))
                    update(
                        CleanupExecutionUpdate(
                            currentItemTitle: item.title,
                            currentItemIndex: index,
                            totalItems: executableItems.count,
                            overallProgress: overallProgress,
                            totalSpaceFreed: spaceFreed + freed
                        )
                    )
                }

            case .fileSelection:
                let selections = makeSelections(for: item)
                result = await cleanupEngine.performBatchCleanup(selections: selections) { current, total, freed in
                    let itemProgress = total > 0 ? Double(current) / Double(total) : 0
                    let overallProgress = (Double(index) + itemProgress) / Double(max(executableItems.count, 1))
                    update(
                        CleanupExecutionUpdate(
                            currentItemTitle: item.title,
                            currentItemIndex: index,
                            totalItems: executableItems.count,
                            overallProgress: overallProgress,
                            totalSpaceFreed: spaceFreed + freed
                        )
                    )
                }

            case .suggestOnly:
                continue
            }

            executedItems.append(item)
            filesDeleted += result.filesDeleted
            spaceFreed += result.spaceFreed
            errors.append(contentsOf: result.errors)
        }

        return CleanupExecutionSummary(
            executedItems: executedItems,
            filesDeleted: filesDeleted,
            spaceFreed: spaceFreed,
            duration: Date().timeIntervalSince(startedAt),
            errors: errors
        )
    }

    private func makeSelections(for item: CleanupPlanItem) -> [FileSelection] {
        item.backingPaths.compactMap { path in
            guard let fileItem = makeFileItem(at: path, riskLevel: item.riskLevel, reason: item.recommendationReason) else {
                return nil
            }
            return FileSelection(file: fileItem, shouldDelete: true)
        }
    }

    private func makeFileItem(at path: String, riskLevel: RiskLevel, reason: String) -> FileItem? {
        guard fileManager.fileExists(atPath: path),
              let attributes = try? fileManager.attributesOfItem(atPath: path),
              let fileType = attributes[.type] as? FileAttributeType,
              fileType == .typeRegular else {
            return nil
        }

        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let created = attributes[.creationDate] as? Date ?? Date()
        let modified = attributes[.modificationDate] as? Date ?? created

        return FileItem(
            url: URL(fileURLWithPath: path),
            size: size,
            created: created,
            modified: modified,
            riskLevel: riskLevel,
            reason: reason
        )
    }
}
