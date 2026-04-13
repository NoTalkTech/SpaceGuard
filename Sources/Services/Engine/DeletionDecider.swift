import Foundation

class DeletionDecider {
    private let riskAnalyzer = RiskAnalyzer()
    private let ruleManager: RuleManager

    init(ruleManager: RuleManager) {
        self.ruleManager = ruleManager
    }

    enum DeletionDecision {
        case skip
        case confirm
        case delete
    }

    /// Enhanced deletion decision using weighted risk assessment
    func shouldDeleteFileWithAssessment(_ file: FileItem, rules: CleanupRules) -> (decision: DeletionDecision, assessment: RiskAssessment?) {
        // First get the base decision from risk assessment
        let baseDecision = shouldDeleteFileWithRiskAssessment(file, rules: rules)

        // Then apply rule combination strategies for additional insights
        let (shouldDeleteByCombination, confidence) = ruleManager.combineRuleStrategies(file, rules)

        // If rule combination strongly suggests deletion (high confidence) and base decision is skip,
        // upgrade to confirm (let user decide)
        if shouldDeleteByCombination && confidence > 80.0 && baseDecision.decision == .skip {
            return (.confirm, baseDecision.assessment)
        }

        // If rule combination strongly suggests keeping (high confidence against deletion)
        // and base decision is delete, downgrade to confirm
        if !shouldDeleteByCombination && confidence > 80.0 && baseDecision.decision == .delete {
            return (.confirm, baseDecision.assessment)
        }

        return baseDecision
    }

    func shouldDeleteFileWithRiskAssessment(_ file: FileItem, rules: CleanupRules) -> (decision: DeletionDecision, assessment: RiskAssessment?) {
        // Perform comprehensive risk assessment
        let assessment = riskAnalyzer.assessRisk(for: file, rules: rules)

        // Apply rules based on risk assessment
        switch assessment.riskLevel {
        case .high:
            if rules.neverDeleteHighRisk {
                return (.skip, assessment)
            }
            // Even if not "never delete", require confirmation for high risk
            return (.confirm, assessment)

        case .medium:
            if rules.confirmMediumRisk {
                return (.confirm, assessment)
            }
            // For medium risk files with low score, consider deletion
            if assessment.riskScore < 40 {
                return (.delete, assessment)
            }
            return (.skip, assessment)

        case .low:
            if rules.autoCleanLowRisk {
                // For low risk files with very low score, auto-delete
                if assessment.riskScore < 20 {
                    return (.delete, assessment)
                }
                // Otherwise confirm for low risk files with moderate score
                return (.confirm, assessment)
            }
            return (.skip, assessment)
        }
    }
}
