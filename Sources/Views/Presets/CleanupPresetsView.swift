import SwiftUI
import Foundation

/// 清理操作类型
enum CleanupActionType {
    case estimateOnly  // 仅预估
    case cleanupNow    // 立即清理
}

/// 预设清理选择视图
struct CleanupPresetsView: View {
    @State private var rules = RulesPersistenceService().loadRules()
    @State private var selectedPreset: CleanupPreset?
    @State private var showCustomPresetEditor = false
    @State private var showApplyConfirmation = false
    @State private var applyingPreset: CleanupPreset?
    @State private var spaceEstimates: [CleanupPreset: Int64] = [:]
    @State private var isLoading = false
    @State private var actionType: CleanupActionType = .estimateOnly
    @State private var operationResult: OperationResult?
    @State private var showOperationResult = false

    // 删除确认
    @State private var showDeleteConfirmation = false
    @State private var deletingPreset: CustomPreset?

    // 批量清理确认
    @State private var showCleanupConfirmation = false
    @State private var cleanupFiles: [FileItem] = []
    @State private var cleanupRules: CleanupRules?
    @State private var scanTask: Task<Void, Never>?

    // 编辑预设
    @State private var editingPreset: CustomPreset?

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
                return "'\(preset.displayName)' can free an estimated \(formatBytes(space)) of space"
            case .cleanup(let result, let preset):
                return "'\(preset.displayName)' completed. Removed \(result.filesDeleted) files and freed \(formatBytes(result.spaceFreed))"
            case .error(let message, let preset):
                if let preset = preset {
                    return "Failed to apply '\(preset.displayName)': \(message)"
                } else {
                    return "Operation failed: \(message)"
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
        VStack(spacing: 0) {
            headerSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    presetGridSection

                    Divider()

                    customPresetSection

                    applyButtonSection

                    resultSection
                }
                .padding()
            }
        }
        .onAppear {
            loadSpaceEstimates()
        }
        .onDisappear {
            // 取消扫描任务
            scanTask?.cancel()
        }
        .sheet(isPresented: $showCustomPresetEditor) {
            CustomPresetEditorView(
                rules: editingPreset?.rules ?? CleanupRules(),
                presetName: editingPreset?.name ?? "",
                isEditing: editingPreset != nil,
                onSave: { customRules, name in
                    if let editingPreset = editingPreset {
                        // 更新现有预设
                        try? updateCustomPreset(editingPreset, with: customRules, name: name)
                    } else {
                        // 创建新预设
                        try? saveCustomPreset(customRules, name: name)
                    }
                    showCustomPresetEditor = false
                    editingPreset = nil
                    loadSpaceEstimates()
                },
                onCancel: {
                    showCustomPresetEditor = false
                    editingPreset = nil
                }
            )
        }
        .alert("Apply Preset", isPresented: $showApplyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Apply") {
                if let preset = applyingPreset {
                    applyPreset(preset)
                }
            }
        } message: {
            if let preset = applyingPreset {
                Text("Apply '\(preset.displayName)'? This will overwrite the current cleanup rules.")
            }
        }
        .alert("Delete Preset", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let preset = deletingPreset {
                    deleteCustomPreset(preset)
                }
            }
        } message: {
            if let preset = deletingPreset {
                Text("Delete '\(preset.name)'? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showCleanupConfirmation) {
            if let rules = cleanupRules {
                CleanupConfirmationView(
                    files: cleanupFiles,
                    rules: rules,
                    onConfirm: { selections in
                        performBatchCleanup(selections)
                        showCleanupConfirmation = false
                    },
                    onCancel: {
                        showCleanupConfirmation = false
                    }
                )
            }
        }
    }

    // MARK: - 视图组件

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preset Cleanup")
                    .font(.headline)

                Spacer()

                // 操作类型选择
                Picker("Action", selection: $actionType) {
                    Text("Estimate Only").tag(CleanupActionType.estimateOnly)
                    Text("Clean Now").tag(CleanupActionType.cleanupNow)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .animated(actionType)
            }

            Text("Choose a cleanup strategy that matches your needs, or create a custom preset.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 操作类型说明
            Group {
                switch actionType {
                case .estimateOnly:
                    Text("Calculates estimated savings without deleting any files.")
                        .font(.caption)
                        .foregroundColor(.blue)
                case .cleanupNow:
                    Text("Applies the preset and performs cleanup on matching files.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .transition(.opacity)
        }
        .padding()
    }

    private var presetGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended Presets")
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPreset = preset
                            }
                        }
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPreset = preset
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var customPresetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Presets")
                .font(.headline)

            if let customPresets = loadCustomPresets(), !customPresets.isEmpty {
                ForEach(customPresets) { customPreset in
                    CustomPresetRowView(
                        preset: customPreset,
                        isSelected: selectedPreset == .custom && editingPreset?.id == customPreset.id,
                        onSelect: {
                            // 选择自定义预设
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPreset = .custom
                                editingPreset = customPreset
                                // 加载自定义预设的规则
                                rules = customPreset.rules
                            }
                        },
                        onEdit: {
                            // 编辑自定义预设
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                editingPreset = customPreset
                                rules = customPreset.rules
                                showCustomPresetEditor = true
                            }
                        },
                        onDelete: {
                            // 删除自定义预设
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                deletingPreset = customPreset
                                showDeleteConfirmation = true
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    editingPreset = nil
                    showCustomPresetEditor = true
                }
            }) {
                Label("Create Custom Preset", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var applyButtonSection: some View {
        HStack {
            Spacer()

            Button("Cancel", role: .cancel) {
                // 取消操作
            }

            Button(action: {
                if let preset = selectedPreset {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        applyingPreset = preset
                        showApplyConfirmation = true
                    }
                }
            }) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    switch actionType {
                    case .estimateOnly:
                        Text("Estimate Space")
                    case .cleanupNow:
                        Text("Clean Now")
                    }
                }
            }
            .disabled(selectedPreset == nil || isLoading)
            .buttonStyle(.borderedProminent)
            .transition(.scale.combined(with: .opacity))
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
                            .scaleEffect(showOperationResult ? 1.0 : 0.8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showOperationResult)

                        Text(result.description)
                            .font(.subheadline)

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showOperationResult = false
                                operationResult = nil
                            }
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.spaceEstimates = estimates
                    self.isLoading = false
                }
            }
        }
    }

    private func applyPreset(_ preset: CleanupPreset) {
        isLoading = true
        operationResult = nil
        showOperationResult = false
        showApplyConfirmation = false

        DispatchQueue.global(qos: .userInitiated).async {
            // 应用预设到规则
            let updatedRules = CleanupPresetManager().applyPreset(preset, to: self.rules)
            RulesPersistenceService().saveRules(updatedRules)

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.operationResult = .estimation(space: estimatedSpace, preset: preset)
                self.showOperationResult = true
                self.isLoading = false
            }
        }
    }

    private func performCleanup(preset: CleanupPreset, rules: CleanupRules) {
        // 首先扫描文件，准备批量确认
        scanTask = Task {
            let scanner = DiskScanner()
            var allFiles: [FileItem] = []

            // 使用默认扫描路径或规则指定的路径
            let scanPaths = rules.includeLocations.isEmpty ? [NSHomeDirectory()] : rules.includeLocations

            for path in scanPaths {
                guard FileManager.default.fileExists(atPath: path) else { continue }

                do {
                    let scanResult = try await scanner.scanDirectory(at: path) { _, _ in }
                    let analyzer = RiskAnalyzer()
                    let analyzedFiles = analyzer.analyzeFiles(scanResult.files, rules: rules)
                    allFiles.append(contentsOf: analyzedFiles)
                } catch {
                    print("扫描错误: \(error)")
                }
            }

            // 过滤符合规则的文件
            let filteredFiles = allFiles.filter { file in
                if file.riskLevel == .low && rules.autoCleanLowRisk {
                    return true
                }
                if file.riskLevel == .medium && rules.confirmMediumRisk {
                    return true
                }
                return false
            }

            // 在主线程显示批量确认对话框
            DispatchQueue.main.async {
                if filteredFiles.isEmpty {
                    self.operationResult = .error(message: "No matching files were found", preset: preset)
                    self.showOperationResult = true
                    self.isLoading = false
                } else {
                    self.cleanupFiles = filteredFiles
                    self.cleanupRules = rules
                    self.showCleanupConfirmation = true
                    self.isLoading = false
                }
            }
        }
    }

    private func performBatchCleanup(_ selections: [FileSelection]) {
        isLoading = true
        let activePreset = applyingPreset ?? selectedPreset

        Task {
            let result = await cleanupEngine.performBatchCleanup(selections: selections) { current, total, freed in
                DispatchQueue.main.async {
                    print("批量清理进度: \(current)/\(total), 已释放: \(formatBytes(freed))")
                }
            }

            DispatchQueue.main.async {
                if result.errors.isEmpty {
                    if let preset = activePreset {
                        self.operationResult = .cleanup(result: result, preset: preset)
                    }
                } else {
                    let errorMessages = result.errors.map { $0.error.localizedDescription }.joined(separator: ", ")
                    if let preset = activePreset {
                        self.operationResult = .error(message: "Errors occurred during cleanup: \(errorMessages)", preset: preset)
                    }
                }
                self.showOperationResult = true
                self.isLoading = false
            }
        }
    }

    private func saveCustomPreset(_ rules: CleanupRules, name: String) throws {
        try presetManager.saveCustomPreset(rules, name: name)
    }

    private func updateCustomPreset(_ preset: CustomPreset, with rules: CleanupRules, name: String) throws {
        var updatedPreset = preset
        updatedPreset.rules = rules
        updatedPreset.name = name
        updatedPreset.lastUsedDate = Date()

        // 先删除旧版本，再保存新版本
        try presetManager.deleteCustomPreset(preset)
        try presetManager.saveCustomPreset(rules, name: name)
    }

    private func loadCustomPresets() -> [CustomPreset]? {
        return presetManager.loadCustomPresets()
    }

    private func deleteCustomPreset(_ preset: CustomPreset) {
        do {
            try presetManager.deleteCustomPreset(preset)

            withAnimation(.easeInOut(duration: 0.3)) {
                showDeleteConfirmation = false
                deletingPreset = nil

                // 如果删除的是当前选中的预设，取消选中
                if selectedPreset == .custom {
                    selectedPreset = nil
                }
            }

            // 刷新自定义预设列表
            loadSpaceEstimates()
        } catch {
            print("Error deleting preset: \(error)")
        }
    }
}

// MARK: - 辅助函数

// formatBytes 函数已在其他文件中定义（如 CleanupScenariosDetector.swift）

// MARK: - 预览

#Preview {
    CleanupPresetsView()
}
