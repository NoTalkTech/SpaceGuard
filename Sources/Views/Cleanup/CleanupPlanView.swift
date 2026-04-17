import SwiftUI

struct CleanupPlanView: View {
    let plan: CleanupPlan
    let onConfirm: ([CleanupPlanItem]) -> Void
    let onCancel: () -> Void

    @State private var selectedItemIDs: Set<UUID>

    init(
        plan: CleanupPlan,
        onConfirm: @escaping ([CleanupPlanItem]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.plan = plan
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedItemIDs = State(initialValue: Set(plan.items.filter(\.defaultSelected).map(\.id)))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summarySection

                    ForEach(plan.items) { item in
                        CleanupPlanCard(
                            item: item,
                            isSelected: binding(for: item.id)
                        )
                    }
                }
                .padding()
            }

            Divider()

            footerSection
        }
        .frame(minWidth: 760, minHeight: 600)
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: plan.health.level == .safe ? "checkmark.shield.fill" : "internaldrive.fill")
                .font(.title2)
                .foregroundColor(headerColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Cleanup Plan")
                    .font(.headline)

                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Health")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                planMetricCard(
                    title: "Current Free",
                    value: plan.health.diskStats.formattedFree,
                    tint: .blue
                )

                planMetricCard(
                    title: "Target Free",
                    value: ByteCountFormatter.string(fromByteCount: plan.health.targetFreeBytes, countStyle: .file),
                    tint: .orange
                )

                planMetricCard(
                    title: "Gap To Goal",
                    value: ByteCountFormatter.string(fromByteCount: plan.health.gapToTargetBytes, countStyle: .file),
                    tint: plan.health.gapToTargetBytes == 0 ? .green : .red
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Selected items")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(selectionSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.05))
            )
        }
    }

    private var footerSection: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.escape)
                .buttonStyle(.plain)

            Spacer()

            Text("\(selectedItems.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Run Cleanup") {
                onConfirm(selectedItems)
            }
            .disabled(selectedItems.isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var selectedItems: [CleanupPlanItem] {
        plan.items.filter { selectedItemIDs.contains($0.id) }
    }

    private var selectedSavings: Int64 {
        selectedItems.reduce(0) { $0 + $1.estimatedSavingsBytes }
    }

    private var projectedFreeBytes: Int64 {
        min(plan.health.diskStats.total, plan.health.diskStats.free + selectedSavings)
    }

    private var projectedGapToGoalBytes: Int64 {
        max(0, plan.health.targetFreeBytes - projectedFreeBytes)
    }

    private var headerColor: Color {
        switch plan.health.level {
        case .safe: return .green
        case .warning: return .orange
        case .urgent: return .red
        }
    }

    private var headerSubtitle: String {
        switch plan.health.level {
        case .safe:
            return "Disk space is already healthy. You can still reclaim low-risk space."
        case .warning:
            return "Disk space is below your target waterline. Review the recommended plan below."
        case .urgent:
            return "Disk space is well below target. Selected scenarios are ordered to recover space safely."
        }
    }

    private var selectionSummary: String {
        let freeText = ByteCountFormatter.string(fromByteCount: projectedFreeBytes, countStyle: .file)
        let selectedText = ByteCountFormatter.string(fromByteCount: selectedSavings, countStyle: .file)

        if projectedGapToGoalBytes == 0 {
            return "Selected actions reclaim \(selectedText) and project free space to \(freeText), which reaches the target."
        }

        let gapText = ByteCountFormatter.string(fromByteCount: projectedGapToGoalBytes, countStyle: .file)
        return "Selected actions reclaim \(selectedText) and project free space to \(freeText), still \(gapText) short of the target."
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedItemIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedItemIDs.insert(id)
                } else {
                    selectedItemIDs.remove(id)
                }
            }
        )
    }

    private func planMetricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.08))
        )
    }
}

#Preview {
    let stats = DiskStats(total: 1_000, used: 850, free: 150)
    let goal = StorageGoal(minimumFreeBytes: 200, minimumFreePercent: 0.10)
    let health = StorageHealthService().makeSnapshot(stats: stats, goal: goal)
    let plan = CleanupPlan(
        createdAt: Date(),
        health: health,
        items: [
            CleanupPlanItem(
                id: UUID(),
                source: .scenario,
                title: "废纸篓",
                summary: "清空用户已删除的文件",
                estimatedSavingsBytes: 40,
                riskLevel: .low,
                recoveryCost: .low,
                regenerability: .nonRegenerable,
                recommended: true,
                defaultSelected: true,
                actionType: .scenarioExecution,
                backingScenario: .trash,
                backingPaths: ["/Users/demo/.Trash"],
                recommendationReason: "用户已删除内容，通常能立即回收空间"
            )
        ],
        totalEstimatedSavingsBytes: 40,
        selectedEstimatedSavingsBytes: 40,
        projectedFreeBytes: 190,
        projectedGapToTargetBytes: 10,
        reachesGoal: false
    )

    return CleanupPlanView(
        plan: plan,
        onConfirm: { _ in },
        onCancel: {}
    )
}
