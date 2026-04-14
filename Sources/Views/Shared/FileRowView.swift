import SwiftUI

struct FileRowView: View {
    let file: FileItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: fileIcon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)

                Text(file.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(file.formattedModified, systemImage: "clock")
                        .lineLimit(1)

                    Text(file.reason)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.9))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(formatBytes(file.size))
                    .font(.caption)
                    .monospacedDigit()

                Text(riskBadge)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(riskColor.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(riskColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.03))
        )
    }

    private var fileIcon: String {
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "log": return "doc.text"
        case "cache", "tmp", "temp": return "archivebox"
        case "zip", "tar", "gz": return "archivebox.fill"
        case "jpg", "jpeg", "png", "gif": return "photo"
        case "mp3", "wav", "m4a": return "music.note"
        case "mp4", "mov", "avi": return "film"
        default: return "doc.fill"
        }
    }

    private var riskColor: Color {
        switch file.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var riskBadge: String {
        switch file.riskLevel {
        case .low: return "Safe"
        case .medium: return "Confirm"
        case .high: return "High"
        }
    }
}
