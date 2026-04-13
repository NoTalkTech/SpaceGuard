import SwiftUI

struct RiskLevelSection: View {
    let level: RiskLevel
    let files: [FileItem]
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void

    private var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: onExpand) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? riskColor : .secondary)
                        .onTapGesture {
                            onToggle()
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(level.rawValue) Risk")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(riskColor)

                            Spacer()

                            Text("\(files.count) files · \(formatBytes(totalSize))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(level.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            // Expanded file list
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files) { file in
                        FileRowView(file: file)
                    }
                }
                .padding(.leading, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(isSelected ? 0.15 : 0.05))
        )
    }

    private var riskColor: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}
