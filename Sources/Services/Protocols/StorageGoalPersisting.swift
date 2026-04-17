import Foundation

protocol StorageGoalPersisting {
    func loadGoal() -> StorageGoal
    func saveGoal(_ goal: StorageGoal)
}
