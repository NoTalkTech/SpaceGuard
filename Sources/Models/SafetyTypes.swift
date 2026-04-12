import Foundation

// MARK: - Safety Types

/// Safety issue types
public enum SafetyIssueType: String {
    case systemFileInclusion = "System file inclusion"
    case applicationRunning = "Application running"
    case lowDiskSpace = "Low disk space"
    case fileInUse = "File in use"
}

/// Safety issue severity
public enum SafetySeverity: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

/// Safety issue description
public struct SafetyIssue {
    public let type: SafetyIssueType
    public let description: String
    public let path: String?
    public let severity: SafetySeverity

    public init(type: SafetyIssueType, description: String, path: String?, severity: SafetySeverity) {
        self.type = type
        self.description = description
        self.path = path
        self.severity = severity
    }
}

/// Safety check result
public struct SafetyCheckResult {
    public let isSafe: Bool
    public let safetyIssues: [SafetyIssue]

    public init(isSafe: Bool, safetyIssues: [SafetyIssue]) {
        self.isSafe = isSafe
        self.safetyIssues = safetyIssues
    }
}