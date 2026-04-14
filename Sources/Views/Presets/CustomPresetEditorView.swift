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
            Text(isEditing ? "Edit Custom Preset" : "Create Custom Preset")
                .font(.headline)

            Form(content: {
                TextField("Preset Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (Optional)", text: $description)
                    .textFieldStyle(.roundedBorder)

                Divider()

                Text("Cleanup Rules")
                    .font(.subheadline)

                // 简化的规则编辑
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Auto-clean low risk files")
                        Spacer()
                        Toggle("", isOn: $tempRules.autoCleanLowRisk)
                    }

                    HStack {
                        Text("Confirm medium risk files")
                        Spacer()
                        Toggle("", isOn: $tempRules.confirmMediumRisk)
                    }

                    HStack {
                        Text("Never delete high risk files")
                        Spacer()
                        Toggle("", isOn: $tempRules.neverDeleteHighRisk)
                    }

                    Divider()

                    HStack {
                        Text("Delete downloads older than (days)")
                        Spacer()
                        TextField("", text: Binding(
                            get: { String(tempRules.deleteDownloadsOlderThanDays) },
                            set: { tempRules.deleteDownloadsOlderThanDays = Int($0) ?? tempRules.deleteDownloadsOlderThanDays }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    }

                    HStack {
                        Text("Delete logs older than (days)")
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
                Button("Cancel", role: .cancel, action: onCancel)

                Spacer()

                Button(isEditing ? "Save Changes" : "Save") {
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
