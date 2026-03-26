import XCTest
@testable import SpaceGuard

final class RiskAnalyzerTests: XCTestCase {

    var analyzer: RiskAnalyzer!
    var mockFileURL: URL!
    var mockFileItem: FileItem!
    var mockRules: CleanupRules!

    override func setUp() {
        super.setUp()
        analyzer = RiskAnalyzer()

        // 创建模拟文件URL（使用临时目录）
        let tempDir = FileManager.default.temporaryDirectory
        mockFileURL = tempDir.appendingPathComponent("testfile.txt")

        // 创建模拟文件
        try? "Test content".write(to: mockFileURL, atomically: true, encoding: .utf8)

        // 创建模拟FileItem
        let attributes = try? FileManager.default.attributesOfItem(atPath: mockFileURL.path)
        let fileSize = attributes?[.size] as? Int64 ?? 1024
        let modDate = attributes?[.modificationDate] as? Date ?? Date()
        let createdDate = attributes?[.creationDate] as? Date ?? modDate

        mockFileItem = FileItem(
            url: mockFileURL,
            size: fileSize,
            created: createdDate,
            modified: modDate,
            riskLevel: .medium,
            reason: "Test file"
        )

        // 创建模拟清理规则
        mockRules = CleanupRules()
    }

    override func tearDown() {
        // 清理临时文件
        try? FileManager.default.removeItem(at: mockFileURL)

        analyzer = nil
        mockFileURL = nil
        mockFileItem = nil
        mockRules = nil

        super.tearDown()
    }

    func testAnalyzerInitialization() {
        XCTAssertNotNil(analyzer)
    }

    func testClassifyRisk() {
        // 测试缓存文件路径（低风险）
        let cacheURL = URL(fileURLWithPath: "/Users/test/Library/Caches/com.test.app/cache.db")
        let cacheRisk = analyzer.classifyRisk(for: cacheURL, rules: mockRules)
        XCTAssertEqual(cacheRisk, .low, "缓存文件应为低风险")

        // 测试系统文件路径（高风险）
        let systemURL = URL(fileURLWithPath: "/System/Library/test")
        let systemRisk = analyzer.classifyRisk(for: systemURL, rules: mockRules)
        XCTAssertEqual(systemRisk, .high, "系统文件应为高风险")

        // 测试用户文档路径（中风险）
        let docURL = URL(fileURLWithPath: "/Users/test/Documents/test.doc")
        let docRisk = analyzer.classifyRisk(for: docURL, rules: mockRules)
        XCTAssertEqual(docRisk, .medium, "用户文档应为中风险")
    }

    func testClassifyRiskWithCustomOverride() {
        // 创建带有自定义风险覆盖的规则
        var rules = CleanupRules()
        let customPath = "/custom/path/file.txt"
        let customOverride = CustomRiskOverride(path: customPath, riskLevel: .low)
        rules.customRiskOverrides.append(customOverride)

        let customURL = URL(fileURLWithPath: customPath)
        let risk = analyzer.classifyRisk(for: customURL, rules: rules)

        XCTAssertEqual(risk, .low, "自定义风险覆盖应生效")
    }

    func testGetRiskReason() {
        // 测试系统文件原因
        let systemURL = URL(fileURLWithPath: "/System/test")
        let systemReason = analyzer.getRiskReason(for: systemURL, riskLevel: .high)
        XCTAssertEqual(systemReason, "System file", "系统文件应返回正确的风险原因")

        // 测试缓存文件原因
        let cacheURL = URL(fileURLWithPath: "/tmp/cache.db")
        let cacheReason = analyzer.getRiskReason(for: cacheURL, riskLevel: .low)
        XCTAssertEqual(cacheReason, "Temporary file", "临时文件应返回正确的风险原因")

        // 测试用户文档原因
        let docURL = URL(fileURLWithPath: "/Users/test/Documents/test.doc")
        let docReason = analyzer.getRiskReason(for: docURL, riskLevel: .medium)
        XCTAssertEqual(docReason, "User document", "用户文档应返回正确的风险原因")
    }

    func testAnalyzeFiles() {
        // 创建文件列表
        let files = [mockFileItem!]

        // 分析文件风险
        let analyzedFiles = analyzer.analyzeFiles(files, rules: mockRules)

        XCTAssertEqual(analyzedFiles.count, files.count, "应分析所有文件")
        XCTAssertNotEqual(analyzedFiles.first?.riskLevel, mockFileItem!.riskLevel, "风险等级应被重新评估")
        XCTAssertFalse(analyzedFiles.first?.reason.isEmpty ?? true, "应有风险原因")
    }

    func testAssessRisk() {
        // 测试风险评估
        let assessment = analyzer.assessRisk(for: mockFileItem, rules: mockRules)

        XCTAssertNotNil(assessment, "应返回风险评估")
        XCTAssertTrue(assessment.riskScore >= 0 && assessment.riskScore <= 100, "风险分数应在0-100之间")
        XCTAssertFalse(assessment.primaryReason.isEmpty, "应有主要风险原因")
        XCTAssertFalse(assessment.factors.isEmpty, "应有风险因素")
        XCTAssertFalse(assessment.recommendedAction.isEmpty, "应有推荐操作")

        // 验证风险等级与分数的一致性
        switch assessment.riskLevel {
        case .high:
            XCTAssertTrue(assessment.riskScore >= 70, "高风险应分数≥70")
        case .medium:
            XCTAssertTrue(assessment.riskScore >= 30 && assessment.riskScore < 70, "中风险应分数在30-70之间")
        case .low:
            XCTAssertTrue(assessment.riskScore < 30, "低风险应分数<30")
        }
    }

    func testAssessRiskPathFactor() {
        // 测试路径因素评估
        let assessment = analyzer.assessRisk(for: mockFileItem, rules: mockRules)

        let pathFactor = assessment.factors.first { $0.name == "Path Classification" }
        XCTAssertNotNil(pathFactor, "应有路径分类因素")
        XCTAssertEqual(pathFactor!.weight, 0.4, accuracy: 0.001, "路径因素权重应为0.4")
    }

    func testAssessRiskAgeFactor() {
        // 测试年龄因素评估
        let assessment = analyzer.assessRisk(for: mockFileItem, rules: mockRules)

        let ageFactor = assessment.factors.first { $0.name == "File Age" }
        XCTAssertNotNil(ageFactor, "应有文件年龄因素")
        XCTAssertEqual(ageFactor!.weight, 0.25, accuracy: 0.001, "年龄因素权重应为0.25")
    }

    func testAssessRiskSizeFactor() {
        // 测试大小因素评估
        let assessment = analyzer.assessRisk(for: mockFileItem, rules: mockRules)

        let sizeFactor = assessment.factors.first { $0.name == "File Size" }
        XCTAssertNotNil(sizeFactor, "应有文件大小因素")
        XCTAssertEqual(sizeFactor!.weight, 0.15, accuracy: 0.001, "大小因素权重应为0.15")
    }

    func testAssessRiskFileTypeFactor() {
        // 测试文件类型因素评估
        let assessment = analyzer.assessRisk(for: mockFileItem, rules: mockRules)

        let typeFactor = assessment.factors.first { $0.name == "File Type" }
        XCTAssertNotNil(typeFactor, "应有文件类型因素")
        XCTAssertEqual(typeFactor!.weight, 0.1, accuracy: 0.001, "文件类型因素权重应为0.1")
    }

    func testAssessRiskLocationFactor() {
        // 测试位置因素评估
        let assessment = analyzer.assessRisk(for: mockFileItem, rules: mockRules)

        let locationFactor = assessment.factors.first { $0.name == "Location" }
        XCTAssertNotNil(locationFactor, "应有位置因素")
        XCTAssertEqual(locationFactor!.weight, 0.05, accuracy: 0.001, "位置因素权重应为0.05")
    }

    func testCalculateRiskStatistics() {
        // 创建不同风险等级的文件
        let lowRiskFile = FileItem(
            url: URL(fileURLWithPath: "/tmp/low.txt"),
            size: 1024,
            created: Date(),
            modified: Date(),
            riskLevel: .low,
            reason: "Low risk"
        )

        let mediumRiskFile = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Documents/medium.doc"),
            size: 2048,
            created: Date(),
            modified: Date(),
            riskLevel: .medium,
            reason: "Medium risk"
        )

        let highRiskFile = FileItem(
            url: URL(fileURLWithPath: "/System/high.sys"),
            size: 4096,
            created: Date(),
            modified: Date(),
            riskLevel: .high,
            reason: "High risk"
        )

        let files = [lowRiskFile, mediumRiskFile, highRiskFile]

        // 计算统计信息
        let stats = analyzer.calculateRiskStatistics(files)

        XCTAssertEqual(stats[.low]?.count, 1, "应有1个低风险文件")
        XCTAssertEqual(stats[.low]?.size, 1024, "低风险文件总大小应为1024字节")

        XCTAssertEqual(stats[.medium]?.count, 1, "应有1个中风险文件")
        XCTAssertEqual(stats[.medium]?.size, 2048, "中风险文件总大小应为2048字节")

        XCTAssertEqual(stats[.high]?.count, 1, "应有1个高风险文件")
        XCTAssertEqual(stats[.high]?.size, 4096, "高风险文件总大小应为4096字节")
    }

    func testRiskAssessmentInit() {
        // 测试RiskAssessment初始化
        let factor = RiskFactor(
            name: "Test Factor",
            description: "Test Description",
            weight: 1.0,
            score: 50.0,
            maxScore: 100.0
        )

        let assessment = RiskAssessment(
            riskLevel: .medium,
            riskScore: 50.0,
            primaryReason: "Test reason",
            factors: [factor]
        )

        XCTAssertEqual(assessment.riskLevel, .medium)
        XCTAssertEqual(assessment.riskScore, 50.0)
        XCTAssertEqual(assessment.primaryReason, "Test reason")
        XCTAssertEqual(assessment.factors.count, 1)
        XCTAssertFalse(assessment.recommendedAction.isEmpty)
    }

    func testRiskAssessmentRecommendedActions() {
        // 测试高风险
        let highAssessment = RiskAssessment(
            riskLevel: .high,
            riskScore: 85.0,
            primaryReason: "High risk file",
            factors: []
        )
        XCTAssertEqual(highAssessment.recommendedAction, "Do not delete")

        // 测试中风险（分数>70）
        let mediumHighAssessment = RiskAssessment(
            riskLevel: .medium,
            riskScore: 75.0,
            primaryReason: "Medium-high risk file",
            factors: []
        )
        XCTAssertEqual(mediumHighAssessment.recommendedAction, "Confirm before deleting")

        // 测试中风险（分数≤70）
        let mediumLowAssessment = RiskAssessment(
            riskLevel: .medium,
            riskScore: 50.0,
            primaryReason: "Medium-low risk file",
            factors: []
        )
        XCTAssertEqual(mediumLowAssessment.recommendedAction, "Consider for deletion")

        // 测试低风险（分数>30）
        let lowHighAssessment = RiskAssessment(
            riskLevel: .low,
            riskScore: 40.0,
            primaryReason: "Low-high risk file",
            factors: []
        )
        XCTAssertEqual(lowHighAssessment.recommendedAction, "Confirm before deleting")

        // 测试低风险（分数≤30）
        let lowLowAssessment = RiskAssessment(
            riskLevel: .low,
            riskScore: 20.0,
            primaryReason: "Low-low risk file",
            factors: []
        )
        XCTAssertEqual(lowLowAssessment.recommendedAction, "Safe to delete automatically")
    }

    // Note: Classification helper methods are private and cannot be tested directly.
    // Their functionality is tested indirectly through the public classifyRisk method.
}