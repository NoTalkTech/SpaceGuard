import Foundation

class DiskScanner {
    private let fileManager = FileManager.default
    private var isScanning = false
    private var cancellationToken: Bool = false

    struct ScanResult {
        let totalSize: Int64
        let fileCount: Int
        let files: [FileItem]
        let duration: TimeInterval
    }

    func scanDirectory(at path: String, progress: @escaping (Int, Int64) -> Void) async throws -> ScanResult {
        guard !isScanning else {
            throw ScanError.alreadyScanning
        }

        isScanning = true
        cancellationToken = false
        let startTime = Date()

        defer {
            isScanning = false
            cancellationToken = false
        }

        let url = URL(fileURLWithPath: path)
        var totalSize: Int64 = 0
        var fileCount = 0
        var files: [FileItem] = []

        // Get directory contents
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { (url, error) -> Bool in
                print("Error accessing \(url): \(error)")
                return true
            }
        )

        guard let enumerator = enumerator else {
            throw ScanError.cannotAccessDirectory(path)
        }

        while let fileURL = enumerator.nextObject() as? URL {
            if cancellationToken {
                throw ScanError.cancelled
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .fileSizeKey,
                    .creationDateKey,
                    .contentModificationDateKey,
                    .isDirectoryKey
                ])

                guard let isDirectory = resourceValues.isDirectory, !isDirectory else {
                    continue
                }

                let size = Int64(resourceValues.fileSize ?? 0)
                totalSize += size
                fileCount += 1

                let fileItem = FileItem(
                    url: fileURL,
                    size: size,
                    created: resourceValues.creationDate ?? Date(),
                    modified: resourceValues.contentModificationDate ?? Date(),
                    riskLevel: .low, // Will be classified later
                    reason: ""
                )

                files.append(fileItem)

                // Report progress every 100 files
                if fileCount % 100 == 0 {
                    progress(fileCount, totalSize)
                }

            } catch {
                print("Error reading file \(fileURL): \(error)")
                continue
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        progress(fileCount, totalSize)

        return ScanResult(
            totalSize: totalSize,
            fileCount: fileCount,
            files: files,
            duration: duration
        )
    }

    func cancelScan() {
        cancellationToken = true
    }

    func getDiskUsage() -> DiskStats? {
        do {
            let fileSystemAttributes = try fileManager.attributesOfFileSystem(forPath: "/")
            let total = (fileSystemAttributes[.systemSize] as? NSNumber)?.int64Value ?? 0
            let free = (fileSystemAttributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            let used = total - free

            return DiskStats(total: total, used: used, free: free)
        } catch {
            print("Error getting disk usage: \(error)")
            return nil
        }
    }

    enum ScanError: LocalizedError {
        case alreadyScanning
        case cannotAccessDirectory(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .alreadyScanning:
                return "A scan is already in progress"
            case .cannotAccessDirectory(let path):
                return "Cannot access directory: \(path)"
            case .cancelled:
                return "Scan was cancelled"
            }
        }
    }
}