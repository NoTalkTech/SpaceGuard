import SwiftUI

struct MenuProgressView: View {
    @ObservedObject var progressTracker: ProgressTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(titleText)
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                if !usesIndeterminateProgress {
                    Text("\(Int(progressTracker.currentProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(progressTracker.currentStatus)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if usesIndeterminateProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                ProgressView(value: progressTracker.currentProgress)
                    .controlSize(.small)
            }

            HStack {
                Text(detailText)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                if progressTracker.spaceFreed > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: progressTracker.spaceFreed, countStyle: .file))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }

    private var isQuickCleanupScan: Bool {
        progressTracker.isCleaning && progressTracker.currentStatus.hasPrefix("Scanning quick cleanup")
    }

    private var usesIndeterminateProgress: Bool {
        progressTracker.isScanning
            || isQuickCleanupScan
            || progressTracker.currentStatus.hasPrefix("Starting")
    }

    private var titleText: String {
        if progressTracker.isScanning {
            return "Disk Analysis"
        }

        if isQuickCleanupScan {
            return "Quick Cleanup Scan"
        }

        if progressTracker.isCleaning {
            return "Quick Cleanup"
        }

        return "SpaceGuard"
    }

    private var detailText: String {
        if usesIndeterminateProgress {
            if progressTracker.filesProcessed > 0 {
                return "\(progressTracker.filesProcessed) files scanned"
            }
            return "Working..."
        }

        return "\(progressTracker.filesProcessed)/\(max(progressTracker.totalFiles, progressTracker.filesProcessed)) files"
    }
}
