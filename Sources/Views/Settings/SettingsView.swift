import SwiftUI

@MainActor
struct SettingsView: View {
    @State private var rules = RulesPersistenceService().loadRules()

    // Dialog states
    @State private var showAddOverride = false
    @State private var showAddPattern = false
    @State private var showConfigureSchedule = false
    @State private var showFileTypeRulesEditor = false

    // Save feedback
    @State private var showSaveSuccess = false
    @State private var saveMessage = ""

    // Reset confirmation
    @State private var showResetConfirmation = false

    // Rule conflicts
    @State private var ruleConflicts: [RuleConflict] = []
    @State private var showRuleConflicts = false

    var body: some View {
        UnifiedSettingsView(
            rules: $rules,
            showResetConfirmation: $showResetConfirmation,
            showAddOverride: $showAddOverride,
            showAddPattern: $showAddPattern,
            showConfigureSchedule: $showConfigureSchedule,
            showFileTypeRulesEditor: $showFileTypeRulesEditor,
            showSaveSuccess: $showSaveSuccess,
            saveMessage: $saveMessage,
            saveRules: saveRules
        )
        .frame(width: 700, height: 500)
        .sheet(isPresented: $showAddOverride) {
            AddCustomRiskOverrideView(
                isPresented: $showAddOverride,
                customRiskOverrides: $rules.customRiskOverrides
            )
            .onDisappear {
                saveRules()
            }
        }
        .sheet(isPresented: $showAddPattern) {
            AddExclusionPatternView(
                isPresented: $showAddPattern,
                exclusionPatterns: $rules.exclusionPatterns
            )
            .onDisappear {
                saveRules()
            }
        }
        .sheet(isPresented: $showConfigureSchedule) {
            ConfigureScheduleView(
                isPresented: $showConfigureSchedule,
                scheduledCleanup: $rules.scheduledCleanup
            )
            .onDisappear {
                saveRules()
            }
        }
        .sheet(isPresented: $showFileTypeRulesEditor) {
            FileTypeRulesEditorView(
                isPresented: $showFileTypeRulesEditor,
                fileTypeRules: $rules.fileTypeRules
            )
            .onDisappear {
                saveRules()
            }
        }
        .overlay(alignment: .bottom) {
            if showSaveSuccess {
                HStack {
                    if ruleConflicts.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .onTapGesture {
                                showRuleConflicts = true
                            }
                    }
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showRuleConflicts) {
            RuleConflictsView(isPresented: $showRuleConflicts, conflicts: ruleConflicts)
        }
    }

    private func saveRules() {
        let ruleManager = RuleManager()
        let (_, conflicts) = ruleManager.validateRules(rules)
        ruleConflicts = conflicts

        if !conflicts.isEmpty {
            showRuleConflicts = true
            saveMessage = "Settings saved with \(conflicts.count) rule conflict(s)"
        } else {
            saveMessage = "Settings saved successfully"
        }

        RulesPersistenceService().saveRules(rules)
        showSaveSuccess = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveSuccess = false
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
