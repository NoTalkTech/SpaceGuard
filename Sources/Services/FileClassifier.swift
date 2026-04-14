import Foundation

class FileClassifier {
    private let fileManager = FileManager.default

    func isSystemFile(_ path: String) -> Bool {
        let home = NSHomeDirectory()
        // 用户主目录下的文件不是系统文件
        if path.hasPrefix(home) {
            return false
        }

        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/Library", "/Applications/Utilities"]
        return systemPaths.contains { path.hasPrefix($0) }
    }

    func isApplicationBundle(_ path: String) -> Bool {
        return path.hasSuffix(".app") || path.contains(".app/")
    }

    func isCriticalUserFile(_ path: String) -> Bool {
        // 检查关键用户数据目录
        let criticalPatterns = [
            "/Library/Application Support/",
            "/Library/Preferences/",
            "/Library/Mail/",
            "/Library/Messages/"
        ]

        // 排除系统目录
        if isSystemFile(path) {
            return false
        }

        // 检查是否匹配任一关键模式
        for pattern in criticalPatterns {
            if path.contains(pattern) {
                return true
            }
        }

        return false
    }

    func isUserDocument(_ path: String) -> Bool {
        // 检查常见用户文档目录模式
        let documentPatterns = [
            "/Documents/",
            "/Desktop/",
            "/Pictures/",
            "/Movies/",
            "/Music/",
            "/Downloads/",
            "/Public/",
            "/Sites/"
        ]

        // 排除系统目录
        if isSystemFile(path) {
            return false
        }

        // 检查是否匹配任一文档模式
        for pattern in documentPatterns {
            if path.contains(pattern) {
                // 对于Downloads目录，排除最近下载
                if pattern == "/Downloads/" {
                    return !isRecentDownload(path)
                }
                return true
            }
        }

        return false
    }

    func isRecentDownload(_ path: String) -> Bool {
        // 检查是否是Downloads目录下的文件
        guard path.contains("/Downloads/") else {
            return false
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let modDate = attributes[.modificationDate] as? Date {
                let daysOld = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
                return daysOld < 30 // Less than 30 days old
            }
        } catch {
            return false
        }

        return false
    }

    func isLogFile(_ path: String) -> Bool {
        return path.contains("Logs") || path.contains(".log") || path.hasSuffix(".log")
    }

    func isCacheFile(_ path: String) -> Bool {
        return path.contains("Caches") || path.contains("Cache.") ||
               path.contains("/tmp/") || path.contains(".cache")
    }

    func isTempFile(_ path: String) -> Bool {
        return path.contains("/tmp/") || path.contains("/var/tmp/") ||
               path.hasPrefix("/private/tmp/") || path.hasPrefix("/private/var/tmp/") ||
               path.contains("/var/folders/") // macOS temporary directory
    }

    func isTrashFile(_ path: String) -> Bool {
        return path.contains(".Trash") || path.contains("Trash") || path.contains("废纸篓")
    }
}
