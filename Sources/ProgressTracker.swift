import Foundation

@MainActor
class ProgressTracker: ObservableObject {
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var currentProgress: Double = 0.0
    @Published var currentStatus: String = "Ready"
    @Published var currentOperation: String = ""
    @Published var filesProcessed: Int = 0
    @Published var totalFiles: Int = 0
    @Published var spaceFreed: Int64 = 0

    private var scanner: DiskScanner?
    private var cleanupEngine: CleanupEngine?

    var confirmDeletion: ((FileItem) async -> Bool)? = nil

    func startScan(path: String = NSHomeDirectory()) async -> DiskScanner.ScanResult? {
        guard !isScanning else { return nil }

        isScanning = true
        currentOperation = "Scanning disk..."
        currentStatus = "Scanning files"
        currentProgress = 0.0
        filesProcessed = 0
        totalFiles = 0
        spaceFreed = 0

        scanner = DiskScanner()

        do {
            let result = try await scanner!.scanDirectory(at: path) { [weak self] processed, totalSize in
                guard let self = self else { return }

                Task { @MainActor in
                    self.filesProcessed = processed
                    if self.totalFiles == 0 {
                        self.totalFiles = processed + 100 // Estimate
                    }
                    self.currentProgress = Double(processed) / Double(max(self.totalFiles, 1))
                    self.currentStatus = "Scanned \(processed) files (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))"
                }
            }

            isScanning = false
            currentStatus = "Scan complete: \(result.fileCount) files, \(ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))"
            currentProgress = 1.0
            filesProcessed = result.fileCount
            totalFiles = result.fileCount

            return result

        } catch {
            isScanning = false
            currentStatus = "Scan failed: \(error.localizedDescription)"
            currentProgress = 0.0
            return nil
        }
    }

    func startCleanup(files: [FileItem], rules: CleanupRules) async -> CleanupEngine.CleanupResult? {
        guard !isCleaning else { return nil }

        isCleaning = true
        currentOperation = "Cleaning up..."
        currentStatus = "Starting cleanup"
        currentProgress = 0.0
        filesProcessed = 0
        totalFiles = files.count
        spaceFreed = 0

        cleanupEngine = CleanupEngine()

        let result = await cleanupEngine!.cleanupFiles(files, rules: rules, progress: { [weak self] processed, total, freed in
            guard let self = self else { return }

            Task { @MainActor in
                self.filesProcessed = processed
                self.totalFiles = total
                self.spaceFreed = freed
                self.currentProgress = Double(processed) / Double(max(total, 1))
                self.currentStatus = "Cleaned \(processed)/\(total) files, freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))"
            }
        }, confirmAction: confirmDeletion)

        isCleaning = false
        currentStatus = "Cleanup complete: \(result.filesDeleted) files deleted, \(ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file)) freed"
        currentProgress = 1.0

        if !result.errors.isEmpty {
            currentStatus += " (\(result.errors.count) errors)"
        }

        return result
    }

    func quickCleanup(rules: CleanupRules) async -> CleanupEngine.CleanupResult? {
        guard !isCleaning else { return nil }

        isCleaning = true
        currentOperation = "Quick cleanup..."
        currentStatus = "Starting quick cleanup"
        currentProgress = 0.0
        filesProcessed = 0
        totalFiles = 0
        spaceFreed = 0

        cleanupEngine = CleanupEngine()

        let result = await cleanupEngine!.quickCleanup(rules: rules, progress: { [weak self] processed, total, freed in
            guard let self = self else { return }

            Task { @MainActor in
                self.filesProcessed = processed
                self.totalFiles = total
                self.spaceFreed = freed
                self.currentProgress = Double(processed) / Double(max(total, 1))
                self.currentStatus = "Cleaned \(processed)/\(total) files, freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))"
            }
        }, confirmAction: confirmDeletion)

        isCleaning = false
        currentStatus = "Quick cleanup complete: \(result.filesDeleted) files deleted, \(ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file)) freed"
        currentProgress = 1.0

        return result
    }

    func cancelScan() {
        scanner?.cancelScan()
        isScanning = false
        currentStatus = "Scan cancelled"
    }

    func cancelCleanup() {
        cleanupEngine?.cancelCleanup()
        isCleaning = false
        currentStatus = "Cleanup cancelled"
    }

    func reset() {
        isScanning = false
        isCleaning = false
        currentProgress = 0.0
        currentStatus = "Ready"
        currentOperation = ""
        filesProcessed = 0
        totalFiles = 0
        spaceFreed = 0
    }
}