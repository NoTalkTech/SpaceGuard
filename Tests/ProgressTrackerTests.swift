import XCTest
@testable import SpaceGuard

@MainActor
final class ProgressTrackerTests: XCTestCase {

    func testStartScanUpdatesProgressAndReturnsResult() async {
        let expectedFile = FileItem(
            url: URL(fileURLWithPath: "/tmp/cache/test.log"),
            size: 2_048,
            created: Date(timeIntervalSince1970: 1_700_000_000),
            modified: Date(timeIntervalSince1970: 1_700_000_100),
            riskLevel: .low,
            reason: "Test fixture"
        )
        let expectedResult = DiskScanner.ScanResult(
            totalSize: expectedFile.size,
            fileCount: 1,
            files: [expectedFile],
            duration: 0.25
        )

        let tracker = ProgressTracker(
            scannerFactory: {
                MockDiskScanner(result: expectedResult, progressEvents: [(1, expectedFile.size)])
            },
            engineFactory: {
                MockCleanupEngine()
            },
            historyManager: CleanupHistoryManager()
        )

        let result = await tracker.startScan(path: "/tmp")

        XCTAssertEqual(result?.fileCount, expectedResult.fileCount)
        XCTAssertEqual(result?.totalSize, expectedResult.totalSize)
        XCTAssertFalse(tracker.isScanning)
        XCTAssertEqual(tracker.filesProcessed, 1)
        XCTAssertEqual(tracker.totalFiles, 1)
        XCTAssertEqual(tracker.currentProgress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(tracker.currentStatus.contains("Scan complete"))
    }

    func testQuickCleanupUpdatesStatusAndRecordsHistory() async {
        let historyManager = CleanupHistoryManager()
        historyManager.clearHistory()

        let cleanupResult = CleanupEngine.CleanupResult(
            filesDeleted: 3,
            spaceFreed: 6_144,
            duration: 0.5,
            errors: []
        )

        let tracker = ProgressTracker(
            scannerFactory: {
                MockDiskScanner(result: .init(totalSize: 0, fileCount: 0, files: [], duration: 0))
            },
            engineFactory: {
                MockCleanupEngine(
                    quickCleanupResult: cleanupResult,
                    quickCleanupProgressEvents: [(1, 3, 1_024), (3, 3, cleanupResult.spaceFreed)]
                )
            },
            historyManager: historyManager
        )

        let result = await tracker.quickCleanup(rules: CleanupRules())

        XCTAssertEqual(result?.filesDeleted, cleanupResult.filesDeleted)
        XCTAssertEqual(result?.spaceFreed, cleanupResult.spaceFreed)
        XCTAssertFalse(tracker.isCleaning)
        XCTAssertEqual(tracker.filesProcessed, 3)
        XCTAssertEqual(tracker.totalFiles, 3)
        XCTAssertEqual(tracker.spaceFreed, cleanupResult.spaceFreed)
        XCTAssertEqual(tracker.currentProgress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(tracker.currentStatus.contains("Quick cleanup complete"))
        XCTAssertEqual(historyManager.records.count, 1)
        XCTAssertEqual(historyManager.records.first?.cleanupType, .quick)
        XCTAssertEqual(historyManager.records.first?.filesDeleted, cleanupResult.filesDeleted)
        XCTAssertEqual(historyManager.records.first?.spaceFreed, cleanupResult.spaceFreed)
    }

    func testSetDisplayStateThrottlesRapidUpdatesButFlushesLatestState() async {
        let tracker = ProgressTracker(
            scannerFactory: {
                MockDiskScanner(result: .init(totalSize: 0, fileCount: 0, files: [], duration: 0))
            },
            engineFactory: {
                MockCleanupEngine()
            },
            historyManager: CleanupHistoryManager(),
            minimumUIUpdateInterval: 0.2
        )

        tracker.setDisplayState(
            isScanning: true,
            currentStatus: "Scanned 100 files",
            filesProcessed: 100,
            totalFiles: 500
        )
        XCTAssertEqual(tracker.currentStatus, "Scanned 100 files")
        XCTAssertEqual(tracker.filesProcessed, 100)

        tracker.setDisplayState(
            currentStatus: "Scanned 200 files",
            filesProcessed: 200,
            totalFiles: 500
        )

        XCTAssertEqual(tracker.currentStatus, "Scanned 100 files")
        XCTAssertEqual(tracker.filesProcessed, 100)

        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(tracker.currentStatus, "Scanned 200 files")
        XCTAssertEqual(tracker.filesProcessed, 200)

        tracker.setDisplayState(
            isScanning: false,
            currentProgress: 1,
            currentStatus: "Scan complete",
            filesProcessed: 500,
            totalFiles: 500,
            force: true
        )

        XCTAssertEqual(tracker.currentStatus, "Scan complete")
        XCTAssertEqual(tracker.currentProgress, 1, accuracy: 0.0001)
        XCTAssertEqual(tracker.filesProcessed, 500)
    }
}

private final class MockDiskScanner: DiskScannerProtocol {
    private let result: DiskScanner.ScanResult
    private let progressEvents: [(Int, Int64)]

    init(result: DiskScanner.ScanResult, progressEvents: [(Int, Int64)] = []) {
        self.result = result
        self.progressEvents = progressEvents
    }

    func scanDirectory(at path: String, progress: @escaping (Int, Int64) -> Void) async throws -> DiskScanner.ScanResult {
        for event in progressEvents {
            progress(event.0, event.1)
        }
        return result
    }

    func getDiskUsage() -> DiskStats? {
        nil
    }

    func cancelScan() {}
}

private final class MockCleanupEngine: CleanupEngineProtocol {
    private let quickCleanupResult: CleanupEngine.CleanupResult
    private let quickCleanupProgressEvents: [(Int, Int, Int64)]

    init(
        quickCleanupResult: CleanupEngine.CleanupResult = .init(filesDeleted: 0, spaceFreed: 0, duration: 0, errors: []),
        quickCleanupProgressEvents: [(Int, Int, Int64)] = []
    ) {
        self.quickCleanupResult = quickCleanupResult
        self.quickCleanupProgressEvents = quickCleanupProgressEvents
    }

    func cleanupFiles(
        _ files: [FileItem],
        rules: CleanupRules,
        progress: @escaping (Int, Int, Int64) -> Void,
        confirmAction: ((FileItem) async -> Bool)?
    ) async -> CleanupEngine.CleanupResult {
        .init(filesDeleted: 0, spaceFreed: 0, duration: 0, errors: [])
    }

    func quickCleanup(
        rules: CleanupRules,
        progress: @escaping (Int, Int, Int64) -> Void,
        confirmAction: ((FileItem) async -> Bool)?
    ) async -> CleanupEngine.CleanupResult {
        for event in quickCleanupProgressEvents {
            progress(event.0, event.1, event.2)
        }
        return quickCleanupResult
    }

    func performBatchCleanup(
        selections: [FileSelection],
        progress: @escaping (Int, Int, Int64) -> Void
    ) async -> CleanupEngine.CleanupResult {
        .init(filesDeleted: 0, spaceFreed: 0, duration: 0, errors: [])
    }

    func cancelCleanup() {}

    func getQuickCleanupPaths() -> [String] {
        []
    }
}
