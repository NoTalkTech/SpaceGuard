import SwiftUI

// MARK: - 自定义预设行视图

struct CustomPresetRowView: View {
    let preset: CustomPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isDeleting = false

    var body: some View {
        HStack {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(.secondary)
                .scaleEffect(isDeleting ? 0.8 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDeleting)

            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.subheadline)

                if let description = preset.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text("创建于 \(formatDate(preset.createdDate))")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovering ? Color.secondary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
