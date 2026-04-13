import SwiftUI

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
