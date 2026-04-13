import SwiftUI

struct RuleConflictsView: View {
    @Binding var isPresented: Bool
    let conflicts: [RuleConflict]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                Text("Rule Conflicts")
                    .font(.headline)

                Spacer()

                // Conflict count badge
                if !conflicts.isEmpty {
                    Text("\(conflicts.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(10)
                }

                // Close button
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()

            Divider()

            if conflicts.isEmpty {
                // No conflicts state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("No Rule Conflicts")
                        .font(.title3)
                        .fontWeight(.medium)

                    Text("All rules are consistent and valid.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Conflicts list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conflicts) { conflict in
                            RuleConflictRow(conflict: conflict)
                        }
                    }
                    .padding()
                }
            }

            // Footer with actions
            Divider()

            HStack {
                // TODO: Add resolve actions or guidance
                // For now, just show informational text
                Text("Review and resolve conflicts in settings")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

private struct RuleConflictRow: View {
    let conflict: RuleConflict

    var severityColor: Color {
        switch conflict.severity {
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    var severityIcon: String {
        switch conflict.severity {
        case .low:
            return "exclamationmark.circle"
        case .medium:
            return "exclamationmark.triangle"
        case .high:
            return "xmark.octagon"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Severity indicator
            VStack {
                Image(systemName: severityIcon)
                    .font(.title3)
                    .foregroundColor(severityColor)

                Spacer()
            }

            // Conflict details
            VStack(alignment: .leading, spacing: 4) {
                // Conflict type
                HStack {
                    Text(conflict.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    // Severity badge
                    Text(conflict.severity.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(severityColor.opacity(0.2))
                        .cornerRadius(4)
                }

                // Conflict description
                Text(conflict.description)
                    .font(.body)
                    .foregroundColor(.primary)

                // TODO: Add resolution suggestions based on conflict type
                // This is where user input could be valuable
                if conflict.severity == .high {
                    Text("High severity: Requires immediate attention")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(severityColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RuleConflictsView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with conflicts
        RuleConflictsView(isPresented: .constant(true), conflicts: [
            RuleConflict(
                type: .pathInclusionExclusion,
                description: "Path '/Users/example/Downloads' is both included and excluded",
                severity: .high
            ),
            RuleConflict(
                type: .fileTypeRule,
                description: "File extension '.log' is both whitelisted and blacklisted",
                severity: .medium
            ),
            RuleConflict(
                type: .customRiskOverride,
                description: "Custom risk override for system path '/System' sets risk to low",
                severity: .high
            )
        ])

        // Preview without conflicts
        RuleConflictsView(isPresented: .constant(true), conflicts: [])
            .previewDisplayName("No Conflicts")
    }
}