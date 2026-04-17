import SwiftUI

struct CleanupPlanCard: View {
    let item: CleanupPlanItem
    @Binding var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Toggle("", isOn: $isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.headline)

                        Spacer()

                        Text(ByteCountFormatter.string(fromByteCount: item.estimatedSavingsBytes, countStyle: .file))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }

                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        pill(title: item.riskLevel.rawValue, color: riskColor)
                        pill(title: recoveryCostTitle, color: recoveryCostColor)

                        if item.regenerability == .regenerable {
                            pill(title: "可重建", color: .blue)
                        }
                    }

                    Text(item.recommendationReason)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !item.backingPaths.isEmpty {
                        Text(item.backingPaths.prefix(2).joined(separator: "\n"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? accentFill : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? accentStroke : Color.clear, lineWidth: 1)
        )
    }

    private var riskColor: Color {
        switch item.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var recoveryCostTitle: String {
        switch item.recoveryCost {
        case .low: return "恢复成本低"
        case .medium: return "恢复成本中"
        case .high: return "恢复成本高"
        }
    }

    private var recoveryCostColor: Color {
        switch item.recoveryCost {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var accentFill: Color {
        riskColor.opacity(0.12)
    }

    private var accentStroke: Color {
        riskColor.opacity(0.35)
    }

    private func pill(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .foregroundColor(color)
    }
}
