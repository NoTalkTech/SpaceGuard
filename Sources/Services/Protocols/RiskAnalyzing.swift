import Foundation

protocol RiskAnalyzing {
    func assessRisk(for file: FileItem, rules: CleanupRules) -> RiskAssessment
    func classifyRisk(for url: URL, rules: CleanupRules?) -> RiskLevel
    func analyzeFiles(_ files: [FileItem], rules: CleanupRules?) -> [FileItem]
    func calculateRiskStatistics(_ files: [FileItem]) -> [RiskLevel: (count: Int, size: Int64)]
}

extension RiskAnalyzer: RiskAnalyzing {}
