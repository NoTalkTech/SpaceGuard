import SwiftUI
import AppKit

struct FilePreviewView: View {
    let fileItem: FileItem
    let previewInfo: FilePreviewer.PreviewInfo
    @Binding var isPresented: Bool
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var previewError: String?
    @State private var isLoadingPreview = false

    // 动画状态
    @State private var isConfirming = false
    @State private var isCancelling = false
    @State private var warningShake = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .scaleEffect(isConfirming ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isConfirming)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileItem.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(fileItem.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .scaleEffect(isCancelling ? 0.9 : 1.0)
                }
                .buttonStyle(.plain)
                .help("Close dialog")
                .accessibilityLabel("Close")
                .onLongPressGesture {
                    isCancelling = true
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPresented = false
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCancelling)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // File Information
                    GroupBox("File Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Size:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(fileItem.formattedSize)
                                    .monospacedDigit()
                            }

                            HStack {
                                Text("Created:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(fileItem.formattedCreated)
                                    .monospacedDigit()
                            }

                            HStack {
                                Text("Modified:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(fileItem.formattedModified)
                                    .monospacedDigit()
                            }

                            HStack {
                                Text("Risk Level:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(fileItem.riskLevel.rawValue)
                                    .foregroundColor(riskColorAnimated)
                                    .fontWeight(.semibold)
                                    .animation(.easeInOut(duration: 0.5), value: UUID())
                            }

                            HStack {
                                Text("Reason:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(fileItem.reason)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                    }

                    // Preview Section
                    if let previewText = previewInfo.previewText {
                        GroupBox("Preview") {
                            ScrollView {
                                Text(previewText)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(4)
                            }
                            .frame(maxHeight: 200)
                        }
                    }

                    // QuickLook Button
                    if previewInfo.canQuickLook {
                        GroupBox {
                            Button(action: {
                                previewError = nil
                                let previewer = FilePreviewer()
                                previewer.showQuickLookPreview(for: fileItem.url)
                            }) {
                                HStack {
                                    Image(systemName: "eye.fill")
                                    Text("Preview with QuickLook")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .help("Open this file in macOS QuickLook preview")
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                        }
                    }

                    // Warning
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("This file is classified as \(fileItem.riskLevel.rawValue) Risk", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(riskColorAnimated)
                                    .accessibilityLabel("Risk warning: \(fileItem.riskLevel.rawValue) risk file")
                                Spacer()
                            }
                            .offset(x: warningShake ? 5 : 0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: warningShake)

                            Text("Are you sure you want to delete this file? This action cannot be undone.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.3)) {
                            warningShake = true
                        }
                    }

                    // Error display
                    if let error = previewError {
                        GroupBox {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Preview error: \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Action Buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                    .help("Cancel and close this dialog")
                    .buttonStyle(.plain)
                    .scaleEffect(isCancelling ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCancelling)
                    .onLongPressGesture {
                        isCancelling = true
                    }

                Spacer()

                Button("Delete File", action: {
                    isConfirming = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onConfirm()
                    }
                })
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .tint(.red)
                    .help("Permanently delete this file")
                    .scaleEffect(isConfirming ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isConfirming)
                    .onLongPressGesture {
                        isConfirming = true
                    }
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 550, maxWidth: 600,
               minHeight: 400, idealHeight: 500, maxHeight: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var iconName: String {
        switch previewInfo.previewType {
        case .text, .code:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .pdf:
            return "doc.fill"
        case .audio:
            return "music.note"
        case .video:
            return "film.fill"
        case .archive:
            return "archivebox.fill"
        case .binary, .unknown:
            return "doc.fill"
        }
    }

    private var riskColorAnimated: Color {
        switch fileItem.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var riskColor: Color {
        switch fileItem.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct FilePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFile = FileItem.sample()[1] // Medium risk file
        let previewer = FilePreviewer()
        let previewInfo = previewer.getPreviewInfo(for: sampleFile)

        FilePreviewView(
            fileItem: sampleFile,
            previewInfo: previewInfo,
            isPresented: .constant(true),
            onConfirm: {},
            onCancel: {}
        )
    }
}
