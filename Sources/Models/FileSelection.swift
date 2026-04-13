import Foundation

/// File selection for batch cleanup
struct FileSelection: Identifiable {
    let id = UUID()
    let file: FileItem
    let shouldDelete: Bool
}
