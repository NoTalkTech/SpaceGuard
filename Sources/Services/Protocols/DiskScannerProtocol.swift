import Foundation

protocol DiskScannerProtocol {
    func scanDirectory(at path: String, progress: @escaping (Int, Int64) -> Void) async throws -> DiskScanner.ScanResult
    func getDiskUsage() -> DiskStats?
    func cancelScan()
}

extension DiskScanner: DiskScannerProtocol {}
