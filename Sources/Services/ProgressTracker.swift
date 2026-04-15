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

    private let scannerFactory: () -> DiskScannerProtocol
    private let engineFactory: () -> CleanupEngineProtocol
    private let historyManager: CleanupHistoryManager
    private let minimumUIUpdateInterval: TimeInterval
    private var lastUIUpdateTime: Date = .distantPast
    private var pendingUIState: ProgressUIState?
    private var scheduledUIFlushTask: Task<Void, Never>?

    private var scanner: DiskScannerProtocol?
    private var cleanupEngine: CleanupEngineProtocol?

    var confirmDeletion: ((FileItem) async -> Bool)? = nil

    init(
        scannerFactory: @escaping () -> DiskScannerProtocol = { DiskScanner() },
        engineFactory: @escaping () -> CleanupEngineProtocol = { CleanupEngine() },
        historyManager: CleanupHistoryManager? = nil,
        minimumUIUpdateInterval: TimeInterval = 0.2
    ) {
        self.scannerFactory = scannerFactory
        self.engineFactory = engineFactory
        self.historyManager = historyManager ?? .shared
        self.minimumUIUpdateInterval = minimumUIUpdateInterval
    }

    func startScan(path: String = NSHomeDirectory()) async -> DiskScanner.ScanResult? {
        guard !isScanning else { return nil }

        setDisplayState(
            isScanning: true,
            isCleaning: false,
            currentProgress: 0.0,
            currentStatus: "Scanning files",
            currentOperation: "Scanning disk...",
            filesProcessed: 0,
            totalFiles: 0,
            spaceFreed: 0,
            force: true
        )

        let newScanner = scannerFactory()
        scanner = newScanner

        do {
            let result = try await newScanner.scanDirectory(at: path) { [weak self] processed, totalSize in
                guard let self = self else { return }

                Task { @MainActor in
                    let estimatedTotalFiles = self.totalFiles == 0 ? processed + 100 : self.totalFiles
                    self.setDisplayState(
                        currentProgress: Double(processed) / Double(max(estimatedTotalFiles, 1)),
                        currentStatus: "Scanned \(processed) files (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))",
                        filesProcessed: processed,
                        totalFiles: estimatedTotalFiles
                    )
                }
            }

            setDisplayState(
                isScanning: false,
                currentProgress: 1.0,
                currentStatus: "Scan complete: \(result.fileCount) files, \(ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))",
                filesProcessed: result.fileCount,
                totalFiles: result.fileCount,
                force: true
            )

            return result

        } catch {
            setDisplayState(
                isScanning: false,
                currentProgress: 0.0,
                currentStatus: "Scan failed: \(error.localizedDescription)",
                force: true
            )
            return nil
        }
    }

    func startCleanup(files: [FileItem], rules: CleanupRules) async -> CleanupEngine.CleanupResult? {
        guard !isCleaning else { return nil }

        setDisplayState(
            isScanning: false,
            isCleaning: true,
            currentProgress: 0.0,
            currentStatus: "Starting cleanup",
            currentOperation: "Cleaning up...",
            filesProcessed: 0,
            totalFiles: files.count,
            spaceFreed: 0,
            force: true
        )

        let engine = engineFactory()
        cleanupEngine = engine

        let result = await engine.cleanupFiles(files, rules: rules, progress: { [weak self] processed, total, freed in
            guard let self = self else { return }

            Task { @MainActor in
                self.setDisplayState(
                    currentProgress: Double(processed) / Double(max(total, 1)),
                    currentStatus: "Cleaned \(processed)/\(total) files, freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))",
                    filesProcessed: processed,
                    totalFiles: total,
                    spaceFreed: freed
                )
            }
        }, confirmAction: confirmDeletion)

        var completionStatus = "Cleanup complete: \(result.filesDeleted) files deleted, \(ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file)) freed"
        if !result.errors.isEmpty {
            completionStatus += " (\(result.errors.count) errors)"
        }
        setDisplayState(
            isCleaning: false,
            currentProgress: 1.0,
            currentStatus: completionStatus,
            filesProcessed: result.filesDeleted,
            totalFiles: files.count,
            spaceFreed: result.spaceFreed,
            force: true
        )

        // Record cleanup history
        let record = CleanupHistoryRecord(
            id: UUID(),
            timestamp: Date(),
            cleanupType: .manual,
            filesDeleted: result.filesDeleted,
            spaceFreed: result.spaceFreed,
            duration: result.duration,
            errors: result.errors.count,
            wasCancelled: false
        )
        historyManager.addRecord(record)

        return result
    }

    func quickCleanup(rules: CleanupRules) async -> CleanupEngine.CleanupResult? {
        guard !isCleaning else { return nil }

        setDisplayState(
            isScanning: false,
            isCleaning: true,
            currentProgress: 0.0,
            currentStatus: "Starting quick cleanup",
            currentOperation: "Quick cleanup...",
            filesProcessed: 0,
            totalFiles: 0,
            spaceFreed: 0,
            force: true
        )

        let engine = engineFactory()
        cleanupEngine = engine

        let result = await engine.quickCleanup(rules: rules, progress: { [weak self] processed, total, freed in
            guard let self = self else { return }

            Task { @MainActor in
                self.setDisplayState(
                    currentProgress: Double(processed) / Double(max(total, 1)),
                    currentStatus: "Cleaned \(processed)/\(total) files, freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))",
                    filesProcessed: processed,
                    totalFiles: total,
                    spaceFreed: freed
                )
            }
        }, confirmAction: confirmDeletion)

        setDisplayState(
            isCleaning: false,
            currentProgress: 1.0,
            currentStatus: "Quick cleanup complete: \(result.filesDeleted) files deleted, \(ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file)) freed",
            filesProcessed: result.filesDeleted,
            totalFiles: max(totalFiles, result.filesDeleted),
            spaceFreed: result.spaceFreed,
            force: true
        )

        // Record cleanup history
        let record = CleanupHistoryRecord(
            id: UUID(),
            timestamp: Date(),
            cleanupType: .quick,
            filesDeleted: result.filesDeleted,
            spaceFreed: result.spaceFreed,
            duration: result.duration,
            errors: result.errors.count,
            wasCancelled: false
        )
        historyManager.addRecord(record)

        return result
    }

    func cancelScan() {
        scanner?.cancelScan()
        setDisplayState(isScanning: false, currentStatus: "Scan cancelled", force: true)
    }

    func cancelCleanup() {
        cleanupEngine?.cancelCleanup()
        setDisplayState(isCleaning: false, currentStatus: "Cleanup cancelled", force: true)
    }

    func reset() {
        setDisplayState(
            isScanning: false,
            isCleaning: false,
            currentProgress: 0.0,
            currentStatus: "Ready",
            currentOperation: "",
            filesProcessed: 0,
            totalFiles: 0,
            spaceFreed: 0,
            force: true
        )
    }

    func setDisplayState(
        isScanning: Bool? = nil,
        isCleaning: Bool? = nil,
        currentProgress: Double? = nil,
        currentStatus: String? = nil,
        currentOperation: String? = nil,
        filesProcessed: Int? = nil,
        totalFiles: Int? = nil,
        spaceFreed: Int64? = nil,
        force: Bool = false
    ) {
        let state = ProgressUIState(
            isScanning: isScanning ?? self.isScanning,
            isCleaning: isCleaning ?? self.isCleaning,
            currentProgress: currentProgress ?? self.currentProgress,
            currentStatus: currentStatus ?? self.currentStatus,
            currentOperation: currentOperation ?? self.currentOperation,
            filesProcessed: filesProcessed ?? self.filesProcessed,
            totalFiles: totalFiles ?? self.totalFiles,
            spaceFreed: spaceFreed ?? self.spaceFreed
        )

        if force || shouldApplyStateImmediately() {
            applyStateImmediately(state)
            return
        }

        pendingUIState = state
        schedulePendingStateFlush()
    }

    private func shouldApplyStateImmediately() -> Bool {
        Date().timeIntervalSince(lastUIUpdateTime) >= minimumUIUpdateInterval
    }

    private func applyStateImmediately(_ state: ProgressUIState) {
        scheduledUIFlushTask?.cancel()
        scheduledUIFlushTask = nil
        pendingUIState = nil

        isScanning = state.isScanning
        isCleaning = state.isCleaning
        currentProgress = state.currentProgress
        currentStatus = state.currentStatus
        currentOperation = state.currentOperation
        filesProcessed = state.filesProcessed
        totalFiles = state.totalFiles
        spaceFreed = state.spaceFreed
        lastUIUpdateTime = Date()
    }

    private func schedulePendingStateFlush() {
        guard scheduledUIFlushTask == nil else { return }

        let delay = max(0, minimumUIUpdateInterval - Date().timeIntervalSince(lastUIUpdateTime))
        scheduledUIFlushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                self?.flushPendingState()
            }
        }
    }

    private func flushPendingState() {
        scheduledUIFlushTask = nil
        guard let state = pendingUIState else { return }
        applyStateImmediately(state)
    }
}

private struct ProgressUIState {
    let isScanning: Bool
    let isCleaning: Bool
    let currentProgress: Double
    let currentStatus: String
    let currentOperation: String
    let filesProcessed: Int
    let totalFiles: Int
    let spaceFreed: Int64
}
