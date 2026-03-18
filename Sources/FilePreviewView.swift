import SwiftUI
import AppKit

struct FilePreviewView: View {
    let fileItem: FileItem
    let previewInfo: FilePreviewer.PreviewInfo
    @Binding var isPresented: Bool
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var showingQuickLook = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)

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
                }
                .buttonStyle(.plain)
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
                                    .foregroundColor(riskColor)
                                    .fontWeight(.semibold)
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
                            Button(action: { showingQuickLook = true }) {
                                HStack {
                                    Image(systemName: "eye.fill")
                                    Text("Preview with QuickLook")
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // Warning
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("This file is classified as Medium Risk", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)

                            Text("Are you sure you want to delete this file? This action cannot be undone.")
                                .font(.caption)
                                .foregroundColor(.secondary)
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

                Spacer()

                Button("Delete File", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .tint(.red)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Show QuickLook if requested
            if showingQuickLook {
                let previewer = FilePreviewer()
                previewer.showQuickLookPreview(for: fileItem.url)
                showingQuickLook = false
            }
        }
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