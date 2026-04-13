import SwiftUI

// MARK: - File Types Settings View
struct FileTypesSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showFileTypeRulesEditor: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // File Type Rules Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Type Rules")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable file type filtering", isOn: .constant(!rules.fileTypeRules.whitelistedExtensions.isEmpty))
                                .help("Only allow specific file extensions to be cleaned")
                                .disabled(true)

                            Spacer()

                            Button("Edit...") {
                                showFileTypeRulesEditor = true
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !rules.fileTypeRules.whitelistedExtensions.isEmpty {
                            Text("Whitelist: \(rules.fileTypeRules.whitelistedExtensions.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#86868b"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Whitelist: (all file types allowed)")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#86868b"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("Blacklist: \(rules.fileTypeRules.blacklistedExtensions.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#86868b"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }
}
