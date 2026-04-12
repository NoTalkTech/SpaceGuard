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
        .frame(minWidth: 500, minHeight: 400)
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
        .alert("删除预设", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let preset = deletingPreset {
                    deleteCustomPreset(preset)
                }
            }
        } message: {
            if let preset = deletingPreset {
                Text("确定要删除'\(preset.name)'预设吗？\n此操作无法撤销。")
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
                .animated(actionType)
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
            .transition(.opacity)

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
            Text("自定义预设")
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
                Label("创建自定义预设", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .transition(.scale.combined(with: .opacity))
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
                        Text("预估空间")
                    case .cleanupNow:
                        Text("立即清理")
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
                    self.operationResult = .error(message: "没有找到符合条件的文件", preset: preset)
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
                        self.operationResult = .error(message: "清理过程中出现错误: \(errorMessages)", preset: preset)
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

// MARK: - 预设卡片视图

struct PresetCardView: View {
    let preset: CleanupPreset
    let isSelected: Bool
    let estimatedSavings: Int64
    let onSelect: () -> Void

    @State private var isPressed = false
    @State private var isHovering = false

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
                    .scaleEffect(isPressed ? 0.9 : 1.0)

                Text(preset.displayName)
                    .font(.headline)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .scaleEffect(isSelected ? 1.0 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
                .fill(isHovering ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
                .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : (isHovering ? 1 : 0))
        )
        .scaleEffect(isPressed ? 0.98 : (isHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onHover { hovering in
            isHovering = hovering
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

    @State private var isHovering = false
    @State private var isDeleting = false

    var body: some View {
        HStack {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(.secondary)
                .scaleEffect(isDeleting ? 0.8 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDeleting)

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
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovering ? Color.secondary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - 自定义预设编辑器视图

struct CustomPresetEditorView: View {
    let rules: CleanupRules
    let presetName: String
    let isEditing: Bool
    let onSave: (CleanupRules, String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var tempRules: CleanupRules

    init(rules: CleanupRules, presetName: String, isEditing: Bool, onSave: @escaping (CleanupRules, String) -> Void, onCancel: @escaping () -> Void) {
        self.rules = rules
        self.presetName = presetName
        self.isEditing = isEditing
        self.onSave = onSave
        self.onCancel = onCancel
        _tempRules = State(initialValue: rules)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "编辑自定义预设" : "创建自定义预设")
                .font(.headline)

            Form(content: {
                TextField("预设名称", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("描述（可选）", text: $description)
                    .textFieldStyle(.roundedBorder)

                Divider()

                Text("清理规则设置")
                    .font(.subheadline)

                // 简化的规则编辑
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("自动清理低风险文件")
                        Spacer()
                        Toggle("", isOn: $tempRules.autoCleanLowRisk)
                    }

                    HStack {
                        Text("确认中等风险文件")
                        Spacer()
                        Toggle("", isOn: $tempRules.confirmMediumRisk)
                    }

                    HStack {
                        Text("永不删除高风险文件")
                        Spacer()
                        Toggle("", isOn: $tempRules.neverDeleteHighRisk)
                    }

                    Divider()

                    HStack {
                        Text("删除下载文件（天）")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(tempRules.deleteDownloadsOlderThanDays) },
                            set: { tempRules.deleteDownloadsOlderThanDays = Int($0) ?? tempRules.deleteDownloadsOlderThanDays }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    }

                    HStack {
                        Text("删除日志文件（天）")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(tempRules.deleteLogsOlderThanDays) },
                            set: { tempRules.deleteLogsOlderThanDays = Int($0) ?? tempRules.deleteLogsOlderThanDays }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    }
                }
                .font(.system(.body))
            })
            .frame(height: 350)

            HStack {
                Button("取消", role: .cancel, action: onCancel)

                Spacer()

                Button(isEditing ? "保存更改" : "保存") {
                    onSave(tempRules, name.isEmpty ? presetName : name)
                }
                .disabled(name.isEmpty && presetName.isEmpty)
            }
        }
        .padding()
        .frame(width: 450, height: 500)
        .onAppear {
            self.name = presetName
            self.tempRules = rules
        }
    }
}

// MARK: - 辅助函数

// formatBytes 函数已在其他文件中定义（如 CleanupScenariosDetector.swift）

// MARK: - 预览

#Preview {
    CleanupPresetsView()
}
