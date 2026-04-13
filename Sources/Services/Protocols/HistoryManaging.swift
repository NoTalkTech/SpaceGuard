import Foundation
import SwiftUI

@MainActor
protocol HistoryManaging: ObservableObject {
    var records: [CleanupHistoryRecord] { get }
    func load()
    func addRecord(_ record: CleanupHistoryRecord)
    func deleteRecord(_ record: CleanupHistoryRecord)
    func clearHistory()
    func generateStatistics() -> CleanupStatistics
}

extension CleanupHistoryManager: HistoryManaging {}
