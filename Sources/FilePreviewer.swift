import Foundation
import QuickLook
import QuickLookUI

class FilePreviewer {
    private let fileManager = FileManager.default
    private var currentDataSource: QuickLookDataSource?

    struct PreviewInfo {
        let path: String
        let size: Int64
        let created: Date
        let modified: Date
        let riskLevel: RiskLevel
        let reason: String
        let previewText: String?
        let previewType: PreviewType
        let canQuickLook: Bool
    }

    enum PreviewType {
        case text
        case image
        case pdf
        case audio
        case video
        case archive
        case code
        case binary
        case unknown
    }

    func getPreviewInfo(for fileItem: FileItem) -> PreviewInfo {
        let path = fileItem.path
        let url = fileItem.url

        // Determine preview type
        let previewType = determinePreviewType(for: path)

        // Get preview text for text files
        let previewText = previewType == .text ? getTextPreview(for: url, maxLines: 10) : nil

        // Check if QuickLook can preview this file
        // Temporarily assume QuickLook can preview most files
        let canQuickLook = true

        return PreviewInfo(
            path: path,
            size: fileItem.size,
            created: fileItem.created,
            modified: fileItem.modified,
            riskLevel: fileItem.riskLevel,
            reason: fileItem.reason,
            previewText: previewText,
            previewType: previewType,
            canQuickLook: canQuickLook
        )
    }

    private func determinePreviewType(for path: String) -> PreviewType {
        let fileExtension = (path as NSString).pathExtension.lowercased()

        // Text files
        let textExtensions = ["txt", "md", "markdown", "rtf", "html", "htm", "xml", "json", "plist", "yml", "yaml", "csv", "tsv", "log"]
        if textExtensions.contains(fileExtension) {
            return .text
        }

        // Code files
        let codeExtensions = ["swift", "py", "js", "ts", "java", "c", "cpp", "h", "hpp", "m", "mm", "go", "rs", "php", "rb", "sh", "bash", "zsh", "ps1", "bat", "cmd"]
        if codeExtensions.contains(fileExtension) {
            return .code
        }

        // Image files
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "webp", "svg", "ico", "icns"]
        if imageExtensions.contains(fileExtension) {
            return .image
        }

        // PDF files
        if fileExtension == "pdf" {
            return .pdf
        }

        // Audio files
        let audioExtensions = ["mp3", "wav", "aac", "m4a", "flac", "ogg", "wma", "aiff", "alac"]
        if audioExtensions.contains(fileExtension) {
            return .audio
        }

        // Video files
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpeg", "mpg"]
        if videoExtensions.contains(fileExtension) {
            return .video
        }

        // Archive files
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "pkg", "iso"]
        if archiveExtensions.contains(fileExtension) {
            return .archive
        }

        // Check file content for text files without extension
        if fileExtension.isEmpty || fileExtension.count > 5 {
            if isLikelyTextFile(at: URL(fileURLWithPath: path)) {
                return .text
            }
        }

        return .binary
    }

    private func getTextPreview(for url: URL, maxLines: Int) -> String? {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            // Read first 8KB for preview
            let data = fileHandle.readData(ofLength: 8192)

            // Try to decode as UTF-8
            if let content = String(data: data, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                let previewLines = Array(lines.prefix(maxLines))
                let preview = previewLines.joined(separator: "\n")

                // If we read the whole file, add ellipsis
                if lines.count > maxLines {
                    return preview + "\n..."
                }
                return preview
            }

            // Try other encodings
            let encodings: [String.Encoding] = [.ascii, .isoLatin1, .macOSRoman, .windowsCP1252]

            for encoding in encodings {
                if let content = String(data: data, encoding: encoding) {
                    let lines = content.components(separatedBy: .newlines)
                    let previewLines = Array(lines.prefix(maxLines))
                    let preview = previewLines.joined(separator: "\n")

                    if lines.count > maxLines {
                        return preview + "\n..."
                    }
                    return preview
                }
            }

        } catch {
            print("Error reading file for preview: \(error)")
        }

        return nil
    }

    private func isLikelyTextFile(at url: URL) -> Bool {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            // Read first 1KB
            let data = fileHandle.readData(ofLength: 1024)

            // Check if data contains null bytes (binary indicator)
            if data.contains(0) {
                return false
            }

            // Try to decode as UTF-8
            if let _ = String(data: data, encoding: .utf8) {
                return true
            }

        } catch {
            return false
        }

        return false
    }

    func showQuickLookPreview(for url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible {
            panel.orderOut(nil as AnyObject?)
        } else {
            // Create and retain the data source
            currentDataSource = QuickLookDataSource(url: url)
            panel.dataSource = currentDataSource
            panel.makeKeyAndOrderFront(nil as AnyObject?)
        }
    }
}

// MARK: - QuickLook Data Source

private class QuickLookDataSource: NSObject, QLPreviewPanelDataSource {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int {
        return 1
    }

    func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> QLPreviewItem {
        return url as QLPreviewItem
    }
}