import SwiftUI

@MainActor
struct SettingsView: View {
    @State private var rules = RulesPersistenceService().loadRules()
    @State private var storageGoal = StorageGoalPersistenceService().loadGoal()

    // Dialog states
    @State private var showAddOverride = false
    @State private var showAddPattern = false
    @State private var showConfigureSchedule = false
    @State private var showFileTypeRulesEditor = false
    @State private var showIncludedLocationsEditor = false
    @State private var showExcludedLocationsEditor = false
    @State private var showAppCachesEditor = false

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
            storageGoal: $storageGoal,
            showResetConfirmation: $showResetConfirmation,
            showAddOverride: $showAddOverride,
            showAddPattern: $showAddPattern,
            showConfigureSchedule: $showConfigureSchedule,
            showFileTypeRulesEditor: $showFileTypeRulesEditor,
            showIncludedLocationsEditor: $showIncludedLocationsEditor,
            showExcludedLocationsEditor: $showExcludedLocationsEditor,
            showAppCachesEditor: $showAppCachesEditor,
            showSaveSuccess: $showSaveSuccess,
            saveMessage: $saveMessage,
            saveSettings: saveSettings
        )
        .frame(width: 700, height: 500)
        .sheet(isPresented: $showAddOverride) {
            AddCustomRiskOverrideView(
                isPresented: $showAddOverride,
                customRiskOverrides: $rules.customRiskOverrides
            )
            .onDisappear {
                saveSettings()
            }
        }
        .sheet(isPresented: $showAddPattern) {
            AddExclusionPatternView(
                isPresented: $showAddPattern,
                exclusionPatterns: $rules.exclusionPatterns
            )
            .onDisappear {
                saveSettings()
            }
        }
        .sheet(isPresented: $showConfigureSchedule) {
            ConfigureScheduleView(
                isPresented: $showConfigureSchedule,
                scheduledCleanup: $rules.scheduledCleanup
            )
            .onDisappear {
                saveSettings()
            }
        }
        .sheet(isPresented: $showFileTypeRulesEditor) {
            FileTypeRulesEditorView(
                isPresented: $showFileTypeRulesEditor,
                fileTypeRules: $rules.fileTypeRules
            )
            .onDisappear {
                saveSettings()
            }
        }
        .sheet(isPresented: $showIncludedLocationsEditor) {
            StringListEditorView(
                isPresented: $showIncludedLocationsEditor,
                items: $rules.includeLocations,
                title: "Included Locations",
                subtitle: "These paths are eligible for rule-driven cleanup.",
                placeholder: "Add location path...",
                emptyStateText: "No included locations configured."
            )
            .onDisappear {
                saveSettings()
            }
        }
        .sheet(isPresented: $showExcludedLocationsEditor) {
            StringListEditorView(
                isPresented: $showExcludedLocationsEditor,
                items: $rules.excludeLocations,
                title: "Excluded Locations",
                subtitle: "Files under these paths are always skipped.",
                placeholder: "Add excluded path...",
                emptyStateText: "No excluded locations configured."
            )
            .onDisappear {
                saveSettings()
            }
        }
        .sheet(isPresented: $showAppCachesEditor) {
            StringListEditorView(
                isPresented: $showAppCachesEditor,
                items: $rules.appCachesToClean,
                title: "App Caches To Clean",
                subtitle: "Bundle identifiers used for app-specific cache cleanup.",
                placeholder: "Add app bundle ID...",
                emptyStateText: "No app cache identifiers configured."
            )
            .onDisappear {
                saveSettings()
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

    private func saveSettings() {
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
        StorageGoalPersistenceService().saveGoal(storageGoal)
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
