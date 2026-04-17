import Foundation

/// 清理场景枚举，对应 macOS 磁盘清理操作手册中的具体清理场景
enum CleanupScenario: String, CaseIterable, Identifiable, Codable {
    case trash = "trash"
    case downloadInstallers = "downloadInstallers"
    case wallpaperCache = "wallpaperCache"
    case jetbrainsCache = "jetbrainsCache"
    case jetbrainsLogs = "jetbrainsLogs"
    case shipItCache = "shipItCache"
    case homebrewCache = "homebrewCache"
    case npmCache = "npmCache"
    case pipCache = "pipCache"

    var id: String { rawValue }

    /// 场景显示名称
    var displayName: String {
        switch self {
        case .trash: return "废纸篓"
        case .downloadInstallers: return "下载目录旧安装包"
        case .wallpaperCache: return "壁纸缓存"
        case .jetbrainsCache: return "JetBrains 缓存"
        case .jetbrainsLogs: return "JetBrains 日志"
        case .shipItCache: return "Electron 更新缓存"
        case .homebrewCache: return "Homebrew 缓存"
        case .npmCache: return "npm 缓存"
        case .pipCache: return "pip 缓存"
        }
    }

    /// 场景详细描述
    var description: String {
        switch self {
        case .trash: return "清空用户废纸篓中的已删除文件"
        case .downloadInstallers: return "清理下载目录中较旧的安装包和压缩安装文件"
        case .wallpaperCache: return "删除 macOS 航拍/动态壁纸视频缓存"
        case .jetbrainsCache: return "清理 JetBrains IDE 的缓存文件"
        case .jetbrainsLogs: return "清理 JetBrains IDE 的日志文件"
        case .shipItCache: return "清理 Electron 应用更新缓存（如 Cursor、Claude Desktop 等）"
        case .homebrewCache: return "清理 Homebrew 的旧包缓存和可清理资源"
        case .npmCache: return "清理 npm 包管理器的缓存"
        case .pipCache: return "清理 pip Python 包管理器的缓存"
        }
    }

    /// 场景默认风险评估等级
    var defaultRiskLevel: RiskLevel {
        switch self {
        case .trash: return .low
        case .downloadInstallers: return .medium
        case .wallpaperCache: return .low
        case .jetbrainsCache: return .low
        case .jetbrainsLogs: return .low
        case .shipItCache: return .low
        case .homebrewCache: return .low
        case .npmCache: return .low
        case .pipCache: return .low
        }
    }

    /// 场景对应的路径模式（用于检测）
    var pathPatterns: [String] {
        switch self {
        case .trash:
            return [NSHomeDirectory() + "/.Trash"]
        case .downloadInstallers:
            return [NSHomeDirectory() + "/Downloads"]
        case .wallpaperCache:
            return [NSHomeDirectory() + "/Library/Application Support/com.apple.wallpaper/aerials"]
        case .jetbrainsCache:
            return [NSHomeDirectory() + "/Library/Caches/JetBrains"]
        case .jetbrainsLogs:
            return [NSHomeDirectory() + "/Library/Logs/JetBrains"]
        case .shipItCache:
            return [NSHomeDirectory() + "/Library/Caches/*.ShipIt"]
        case .homebrewCache:
            // Homebrew 缓存路径可能因架构而异
            let brewPrefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] ?? "/opt/homebrew"
            return [brewPrefix + "/Cache", brewPrefix + "/Cellar"]
        case .npmCache:
            return [NSHomeDirectory() + "/.npm"]
        case .pipCache:
            // pip 缓存路径可能因平台而异
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? ""
            return [cacheDir + "/pip", NSHomeDirectory() + "/Library/Caches/pip"]
        }
    }

    /// 场景清理命令（用于预估和执行）
    var cleanupCommand: String? {
        switch self {
        case .homebrewCache:
            return "brew cleanup -s"
        case .npmCache:
            return "npm cache clean --force"
        case .pipCache:
            return "pip3 cache purge"
        default:
            return nil
        }
    }

    /// 是否支持命令执行（true）或文件删除（false）
    var usesCommandLine: Bool {
        return cleanupCommand != nil
    }
}

/// 场景检测结果
struct ScenarioDetectionResult: Identifiable {
    let id = UUID()
    let scenario: CleanupScenario
    let detected: Bool
    let estimatedSpace: Int64 // 字节
    let detectedPaths: [String]
    let lastModified: Date?

    var formattedSpace: String {
        formatBytes(estimatedSpace)
    }
}

/// 场景清理建议
struct CleanupRecommendation: Identifiable {
    let id = UUID()
    let scenario: CleanupScenario
    let priority: Int // 1-5，1为最高优先级
    let reason: String
    let estimatedSavings: Int64
}
