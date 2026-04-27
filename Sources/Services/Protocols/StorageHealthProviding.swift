import Foundation

protocol StorageHealthProviding {
    func makeSnapshot(stats: DiskStats, goal: StorageGoal) -> StorageHealthSnapshot
}
