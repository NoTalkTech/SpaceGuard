import SwiftUI

// MARK: - Risk Management Settings View
struct RiskManagementSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showAddOverride: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Custom Risk Overrides Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Risk Overrides")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        if rules.customRiskOverrides.isEmpty {
                            Text("No custom risk overrides")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#86868b"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(rules.customRiskOverrides) { override in
                                    HStack {
                                        Text(override.path)
                                            .font(.system(size: 13, weight: .regular))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        Text(override.riskLevel.rawValue)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(Color(hex: "#86868b"))
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .onDelete { indices in
                                    rules.customRiskOverrides.remove(atOffsets: indices)
                                }
                            }
                            .frame(maxHeight: 120)
                        }

                        HStack {
                            Button("Add Custom Override") {
                                showAddOverride = true
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }
}
