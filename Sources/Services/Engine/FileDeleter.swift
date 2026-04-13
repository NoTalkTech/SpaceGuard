import Foundation

class FileDeleter {
    private let fileManager = FileManager.default

    func deleteFile(_ file: FileItem) throws {
        let url = file.url

        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        // Try to move to trash first (safer)
        if #available(macOS 10.8, *) {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
            print("Moved to trash: \(url.path)")
        } else {
            // Fallback: permanent delete
            try fileManager.removeItem(at: url)
            print("Permanently deleted: \(url.path)")
        }
    }

    func executeCommand(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
