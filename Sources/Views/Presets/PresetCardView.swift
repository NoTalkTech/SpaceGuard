import SwiftUI

// MARK: - 预设卡片视图

struct PresetCardView: View {
    let preset: CleanupPreset
    let isSelected: Bool
    let estimatedSavings: Int64
    let onSelect: () -> Void

    @State private var isHovering = false

    private var riskLevel: RiskLevel {
        // 根据预设类型返回风险等级
        switch preset {
        case .safe:
            return .low
        case .developer:
            return .medium
        case .advanced:
            return .medium
        case .custom:
            return .medium
        }
    }

    private var riskColor: Color {
        switch riskLevel {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: preset.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)

                Text(preset.displayName)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }

            Text(preset.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label(formatBytes(estimatedSavings), systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label(riskLevel.description, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(riskColor)
            }

            let scenarioCount = preset.includedScenarios.count
            if scenarioCount > 0 {
                Text("Includes \(scenarioCount) cleanup scenarios")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(isSelected ? 0.08 : 0.05))
                .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(isHovering ? 0.18 : 0.08),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
