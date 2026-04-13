import SwiftUI

// MARK: - 预设卡片视图

struct PresetCardView: View {
    let preset: CleanupPreset
    let isSelected: Bool
    let estimatedSavings: Int64
    let onSelect: () -> Void

    @State private var isPressed = false
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
            // 图标和标题行
            HStack {
                Image(systemName: preset.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .scaleEffect(isPressed ? 0.9 : 1.0)

                Text(preset.displayName)
                    .font(.headline)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .scaleEffect(isSelected ? 1.0 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
            }

            // 描述
            Text(preset.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // 统计信息
            HStack {
                Label(formatBytes(estimatedSavings), systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label(riskLevel.description, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(riskColor)
            }

            // 包含的场景数量
            let scenarioCount = preset.includedScenarios.count
            if scenarioCount > 0 {
                Text("包含 \(scenarioCount) 个清理场景")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
                .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : (isHovering ? 1 : 0))
        )
        .scaleEffect(isPressed ? 0.98 : (isHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
