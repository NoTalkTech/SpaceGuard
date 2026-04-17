import Foundation

struct StorageGoalPersistenceService: StorageGoalPersisting {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadGoal() -> StorageGoal {
        var goal = StorageGoal()

        if defaults.object(forKey: "cleanupGoal.minimumFreeBytes") != nil {
            goal.minimumFreeBytes = defaults.object(forKey: "cleanupGoal.minimumFreeBytes") as? Int64
                ?? Int64(defaults.integer(forKey: "cleanupGoal.minimumFreeBytes"))
        }

        if defaults.object(forKey: "cleanupGoal.minimumFreePercent") != nil {
            goal.minimumFreePercent = defaults.double(forKey: "cleanupGoal.minimumFreePercent")
        }

        return goal
    }

    func saveGoal(_ goal: StorageGoal) {
        defaults.set(goal.minimumFreeBytes, forKey: "cleanupGoal.minimumFreeBytes")
        defaults.set(goal.minimumFreePercent, forKey: "cleanupGoal.minimumFreePercent")
    }
}
