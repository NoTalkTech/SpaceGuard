import SwiftUI

struct CleanupProgressView: View {
    @ObservedObject var progressTracker: ProgressTracker
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            headerSection

            // Progress bar
            progressSection

            // Stats
            statsSection

            // Cancel button
            if progressTracker.isScanning || progressTracker.isCleaning {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
        .padding(30)
        .frame(width: 500)
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(iconColor)
                    .rotationEffect(.degrees(isActive ? 360 : 0))
                    .animation(
                        isActive ?
                            .linear(duration: 2.0).repeatForever(autoreverses: false) :
                            .default,
                        value: isActive
                    )
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
            }

            // Phase text
            Text(phaseText)
                .font(.system(size: 20, weight: .semibold))

            // Subtitle
            Text(phaseSubtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: progressTracker.currentProgress) {
                Text(progressTracker.currentStatus)
            }
            .progressViewStyle(AnimatedProgressStyle(isActive: isActive))

            HStack {
                Text("\(progressTracker.filesProcessed)/\(progressTracker.totalFiles) files")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(progressTracker.currentProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 20) {
            StatItem(
                icon: "internaldrive",
                label: "Space Freed",
                value: ByteCountFormatter.string(fromByteCount: progressTracker.spaceFreed, countStyle: .file),
                color: .green
            )

            if isActive {
                Divider()
                    .frame(height: 40)

                // Animated dots
                LiveActivityIndicator()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Helpers

    private var isActive: Bool {
        progressTracker.isScanning || progressTracker.isCleaning
    }

    private var iconName: String {
        if progressTracker.isScanning {
            return "magnifyingglass"
        } else if progressTracker.isCleaning {
            return "trash"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        if progressTracker.isScanning {
            return .blue
        } else if progressTracker.isCleaning {
            return .orange
        } else {
            return .green
        }
    }

    private var phaseText: String {
        if progressTracker.isScanning {
            return "Scanning Files"
        } else if progressTracker.isCleaning {
            return "Cleaning Up"
        } else {
            return "Complete"
        }
    }

    private var phaseSubtitle: String {
        if progressTracker.isScanning {
            return "Finding files to clean"
        } else if progressTracker.isCleaning {
            return "Removing files safely"
        } else {
            return "Operation finished"
        }
    }
}

// MARK: - Supporting Views

private struct AnimatedProgressStyle: ProgressViewStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                        .frame(width: max(0, geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0)), height: 12)

                    if isActive {
                        AnimatedPulseOverlay()
                            .frame(width: max(0, geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0)), height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(height: 12)
        }
    }
}

private struct AnimatedPulseOverlay: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        Color.white
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
    }
}

private struct LiveActivityIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue.opacity(0.6 + Double(index) * 0.2))
                    .frame(width: 8, height: 8)
                    .scaleEffect(scale(for: index))
                    .animation(animation(for: index), value: Date())
            }
        }
    }

    private func scale(for index: Int) -> CGFloat {
        let time = Date().timeIntervalSince1970
        let offset = Double(index) * 0.3
        let phase = (time + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.6 + sin(phase * .pi * 2) * 0.4
    }

    private func animation(for index: Int) -> Animation {
        return Animation.linear(duration: 0.3)
            .delay(Double(index) * 0.1)
            .repeatForever(autoreverses: true)
    }
}

private struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 13, weight: .semibold))

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
