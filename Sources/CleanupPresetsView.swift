import SwiftUI
import Foundation

/// 清理操作类型
enum CleanupActionType {
    case estimateOnly  // 仅预估
    case cleanupNow    // 立即清理
}

/// 预设清理选择视图
struct CleanupPresetsView: View {
    @State private var rules = CleanupRules.load()
    @State private var selectedPreset: CleanupPreset?
    @State private var showCustomPresetEditor = false
    @State private var showApplyConfirmation = false
    @State private var applyingPreset: CleanupPreset?
    @State private var spaceEstimates: [CleanupPreset: Int64] = [:]
    @State private var isLoading = false
    @State private var actionType: CleanupActionType = .estimateOnly
    @State private var operationResult: OperationResult?
    @State private var showOperationResult = false

    private let presetManager = CleanupPresetManager()
    private let estimator = SpaceEstimator()
    private let cleanupEngine = CleanupEngine()

    enum OperationResult {
        case estimation(space: Int64, preset: CleanupPreset)
        case cleanup(result: CleanupEngine.CleanupResult, preset: CleanupPreset)
        case error(message: String, preset: CleanupPreset?)

        var description: String {
            switch self {
            case .estimation(let space, let preset):
                return "预估'\(preset.displayName)'预设可节省 \(formatBytes(space)) 空间"
            case .cleanup(let result, let preset):
                return "应用'\(preset.displayName)'预设完成，删除了 \(result.filesDeleted) 个文件，释放了 \(formatBytes(result.spaceFreed)) 空间"
            case .error(let message, let preset):
                if let preset = preset {
                    return "应用'\(preset.displayName)'预设时出错: \(message)"
                } else {
                    return "操作出错: \(message)"
                }
            }
        }

        var isSuccess: Bool {
            switch self {
            case .estimation, .cleanup:
                return true
            case .error:
                return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题和描述
            headerSection

            // 预设卡片网格
            presetGridSection

            // 自定义预设部分
            customPresetSection

            // 应用按钮
            applyButtonSection

            // 操作结果
            resultSection

            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadSpaceEstimates()
        }
        .sheet(isPresented: $showCustomPresetEditor) {
            CustomPresetEditorView(
                onSave: { customRules, name in
                    try? saveCustomPreset(customRules, name: name)
                    showCustomPresetEditor = false
                },
                onCancel: {
                    showCustomPresetEditor = false
                }
            )
        }
        .alert("应用预设", isPresented: $showApplyConfirmation) {
            Button("取消", role: .cancel) { }
            Button("应用") {
                if let preset = applyingPreset {
                    applyPreset(preset)
                }
            }
        } message: {
            if let preset = applyingPreset {
                Text("确定要应用'\(preset.displayName)'预设吗？\n这将覆盖当前的清理规则设置。")
            }
        }
    }

    // MARK: - 视图组件

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("预设清理策略")
                    .font(.largeTitle)
                    .bold()

                Spacer()

                // 操作类型选择
                Picker("操作类型", selection: $actionType) {
                    Text("仅预估").tag(CleanupActionType.estimateOnly)
                    Text("立即清理").tag(CleanupActionType.cleanupNow)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Text("选择最适合您需求的清理策略，或创建自定义预设")
                .font(.body)
                .foregroundColor(.secondary)

            // 操作类型说明
            Group {
                switch actionType {
                case .estimateOnly:
                    Text("仅计算预估空间节省，不会删除任何文件")
                        .font(.caption)
                        .foregroundColor(.blue)
                case .cleanupNow:
                    Text("将应用预设并执行清理操作，删除符合条件的文件")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Divider()
        }
    }

    private var presetGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("推荐预设")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(CleanupPreset.allCases.filter { $0 != .custom }) { preset in
                    PresetCardView(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        estimatedSavings: spaceEstimates[preset] ?? 0,
                        onSelect: {
                            selectedPreset = preset
                        }
                    )
                    .onTapGesture {
                        selectedPreset = preset
                    }
                }
            }
        }
    }

    private var customPresetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自定义预设")
                .font(.headline)

            if let customPresets = loadCustomPresets(), !customPresets.isEmpty {
                ForEach(customPresets) { customPreset in
                    CustomPresetRowView(
                        preset: customPreset,
                        isSelected: false,
                        onSelect: {
                            // 选择自定义预设
                            selectedPreset = .custom
                            // 这里需要加载自定义预设的规则
                        },
                        onEdit: {
                            // 编辑自定义预设
                        },
                        onDelete: {
                            // 删除自定义预设
                        }
                    )
                }
            }

            Button(action: {
                showCustomPresetEditor = true
            }) {
                Label("创建自定义预设", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
    }

    private var applyButtonSection: some View {
        HStack {
            Spacer()

            Button("取消", role: .cancel) {
                // 取消操作
            }

            Button(action: {
                if let preset = selectedPreset {
                    applyingPreset = preset
                    showApplyConfirmation = true
                }
            }) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    switch actionType {
                    case .estimateOnly:
                        Text("预估空间")
                    case .cleanupNow:
                        Text("立即清理")
                    }
                }
            }
            .disabled(selectedPreset == nil || isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 20)
    }

    private var resultSection: some View {
        Group {
            if showOperationResult, let result = operationResult {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(result.isSuccess ? .green : .orange)

                        Text(result.description)
                            .font(.subheadline)

                        Spacer()

                        Button(action: {
                            showOperationResult = false
                            operationResult = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(result.isSuccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    )
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - 操作方法

    private func loadSpaceEstimates() {
        isLoading = true

        // 异步加载空间预估
        DispatchQueue.global(qos: .userInitiated).async {
            var estimates: [CleanupPreset: Int64] = [:]
            for preset in CleanupPreset.allCases {
                if preset == .custom {
                    // 自定义预设的空间预估需要单独计算
                    estimates[preset] = 0
                } else {
                    estimates[preset] = preset.estimatedSavings()
                }
            }

            DispatchQueue.main.async {
                self.spaceEstimates = estimates
                self.isLoading = false
            }
        }
    }

    private func applyPreset(_ preset: CleanupPreset) {
        isLoading = true
        operationResult = nil
        showOperationResult = false

        DispatchQueue.global(qos: .userInitiated).async {
            // 应用预设到规则
            var updatedRules = self.rules
            updatedRules.applyPreset(preset)
            updatedRules.save()

            // 根据操作类型执行不同操作
            switch self.actionType {
            case .estimateOnly:
                self.performEstimation(preset: preset, rules: updatedRules)

            case .cleanupNow:
                self.performCleanup(preset: preset, rules: updatedRules)
            }
        }
    }

    private func performEstimation(preset: CleanupPreset, rules: CleanupRules) {
        // 预估空间
        let estimatedSpace = cleanupEngine.estimateCleanupSpace(rules: rules)

        DispatchQueue.main.async {
            self.operationResult = .estimation(space: estimatedSpace, preset: preset)
            self.showOperationResult = true
            self.isLoading = false
        }
    }

    private func performCleanup(preset: CleanupPreset, rules: CleanupRules) {
        // 执行清理
        let group = DispatchGroup()
        group.enter()

        Task {
            let result = await cleanupEngine.performSafeCleanup(rules: rules) { current, total, freed in
                // 进度更新可以在主线程处理
                DispatchQueue.main.async {
                    // 这里可以添加进度显示逻辑
                    // 目前我们只记录日志
                    print("清理进度: \(current)/\(total), 已释放: \(formatBytes(freed))")
                }
            }

            DispatchQueue.main.async {
                if result.errors.isEmpty {
                    self.operationResult = .cleanup(result: result, preset: preset)
                } else {
                    let errorMessages = result.errors.map { $0.error.localizedDescription }.joined(separator: ", ")
                    self.operationResult = .error(message: "清理过程中出现错误: \(errorMessages)", preset: preset)
                }
                self.showOperationResult = true
                self.isLoading = false
            }

            group.leave()
        }

        group.wait()
    }

    private func saveCustomPreset(_ rules: CleanupRules, name: String) throws {
        try presetManager.saveCustomPreset(rules, name: name)
    }

    private func loadCustomPresets() -> [CustomPreset]? {
        return presetManager.loadCustomPresets()
    }

    private func showSuccessMessage(_ message: String) {
        // TODO: 实现成功消息提示
        print("Success: \(message)")
    }
}

// MARK: - 预设卡片视图

struct PresetCardView: View {
    let preset: CleanupPreset
    let isSelected: Bool
    let estimatedSavings: Int64
    let onSelect: () -> Void

    private var riskLevel: RiskLevel {
        // 根据预设类型返回风险等级
        switch preset {
        case .safe:
            return .low
        case .developer:
            return .medium
        case .advanced:
            return .medium
        case .custom:
            return .medium
        }
    }

    private var riskColor: Color {
        switch riskLevel {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图标和标题行
            HStack {
                Image(systemName: preset.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text(preset.displayName)
                    .font(.headline)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }

            // 描述
            Text(preset.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // 统计信息
            HStack {
                Label(formatBytes(estimatedSavings), systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label(riskLevel.description, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(riskColor)
            }

            // 包含的场景数量
            let scenarioCount = preset.includedScenarios.count
            if scenarioCount > 0 {
                Text("包含 \(scenarioCount) 个清理场景")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - 自定义预设行视图

struct CustomPresetRowView: View {
    let preset: CustomPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.subheadline)

                if let description = preset.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text("创建于 \(formatDate(preset.createdDate))")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - 自定义预设编辑器视图（占位符）

struct CustomPresetEditorView: View {
    let onSave: (CleanupRules, String) -> Void
    let onCancel: () -> Void

    @State private var presetName = ""
    @State private var rules = CleanupRules()

    var body: some View {
        VStack(spacing: 20) {
            Text("创建自定义预设")
                .font(.headline)

            Form {
                TextField("预设名称", text: $presetName)

                // TODO: 添加自定义规则编辑器
                Text("自定义预设编辑器功能待实现")
                    .foregroundColor(.secondary)
            }
            .frame(height: 200)

            HStack {
                Button("取消", role: .cancel, action: onCancel)

                Spacer()

                Button("保存") {
                    onSave(rules, presetName)
                }
                .disabled(presetName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - 辅助函数

// formatBytes 函数已在其他文件中定义（如 CleanupScenariosDetector.swift）

// MARK: - 预览

#Preview {
    CleanupPresetsView()
}