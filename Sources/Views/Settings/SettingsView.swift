import SwiftUI

@MainActor
struct SettingsView: View {
    @EnvironmentObject var historyManager: CleanupHistoryManager
    @StateObject private var progressTracker: ProgressTracker
    @State private var rules = RulesPersistenceService().loadRules()
    @State private var diskStats: DiskStats?

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

    // Sidebar selection
    @State private var selectedTab: SidebarTab = .general

    init(progressTracker: ProgressTracker, initialTab: SidebarTab = .general) {
        _progressTracker = StateObject(wrappedValue: progressTracker)
        _selectedTab = State(initialValue: initialTab)
    }

    init(initialTab: SidebarTab = .general) {
        _progressTracker = StateObject(wrappedValue: ProgressTracker())
        _selectedTab = State(initialValue: initialTab)
    }

    enum SidebarTab: String, CaseIterable {
        case general = "General"
        case cleanup = "Cleanup"
        case fileTypes = "File Types"
        case riskManagement = "Risk Management"
        case diskInfo = "Disk Info"
        case advanced = "Advanced"
        case presetCleanup = "Preset Cleanup"
        case history = "History"
        case statistics = "Statistics"

        var icon: String {
            switch self {
            case .general: return "gear"
            case .cleanup: return "trash"
            case .fileTypes: return "doc.text"
            case .riskManagement: return "exclamationmark.triangle"
            case .diskInfo: return "internaldrive"
            case .advanced: return "slider.horizontal.3"
            case .presetCleanup: return "checklist"
            case .history: return "clock.arrow.circlepath"
            case .statistics: return "chart.bar.xaxis"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(SidebarTab.allCases, id: \.self) { tab in
                            HStack {
                                Image(systemName: tab.icon)
                                    .frame(width: 20, height: 20)
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: .regular))
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                            )
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(width: 200)
                .background(Color(hex: "#b3b3b3").opacity(0.1))
            }
            .frame(width: 200)
            .background(Color(hex: "#b3b3b3").opacity(0.1))

            Divider()

            // Content area
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(
                        rules: $rules,
                        showResetConfirmation: $showResetConfirmation,
                        showSaveSuccess: $showSaveSuccess,
                        saveMessage: $saveMessage,
                        saveRules: saveRules
                    )
                case .cleanup:
                    CleanupSettingsView(
                        progressTracker: progressTracker,
                        rules: rules,
                        diskStats: diskStats,
                        loadDiskStats: loadDiskStats,
                        historyManager: historyManager
                    )
                case .fileTypes:
                    FileTypesSettingsView(
                        rules: $rules,
                        showFileTypeRulesEditor: $showFileTypeRulesEditor
                    )
                case .riskManagement:
                    RiskManagementSettingsView(
                        rules: $rules,
                        showAddOverride: $showAddOverride
                    )
                case .diskInfo:
                    DiskInfoSettingsView(rules: $rules)
                case .presetCleanup:
                    CleanupPresetsView()
                case .history:
                    CleanupHistoryView(historyManager: historyManager)
                case .statistics:
                    CleanupStatisticsView(historyManager: historyManager)
                case .advanced:
                    AdvancedSettingsView(
                        rules: $rules,
                        showAddPattern: $showAddPattern,
                        showConfigureSchedule: $showConfigureSchedule
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 700, height: 500)
        .onAppear {
            loadDiskStats()
        }
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
        .overlay(
            Group {
                if showSaveSuccess {
                    VStack {
                        Spacer()
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showSaveSuccess)
                }
            }
        )
        .sheet(isPresented: $showRuleConflicts) {
            RuleConflictsView(isPresented: $showRuleConflicts, conflicts: ruleConflicts)
        }
    }

    private func loadDiskStats() {
        let scanner = DiskScanner()
        diskStats = scanner.getDiskUsage()
    }

    private func saveRules() {
        // Validate rules before saving
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

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveSuccess = false
        }
    }

}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(CleanupHistoryManager.shared)
    }
}
