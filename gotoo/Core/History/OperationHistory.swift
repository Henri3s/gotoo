import Foundation
import Observation

/// 操作历史和撤销栈 — 记录所有文件操作并支持撤销
@Observable
@MainActor
final class OperationHistory {
    var entries: [HistoryEntry] = []
    var undoStack: [UndoableOperation] = []
    
    struct HistoryEntry: Identifiable {
        let id = UUID()
        let date: Date
        let operation: String
        let source: String
        let destination: String?
        let success: Bool
        let errorMessage: String?
        let undoable: Bool
    }
    
    struct UndoableOperation {
        let type: UndoType
        let sourceURL: URL
        let destinationURL: URL?
        let originalName: String?   // 用于 rename 撤销
        let originalTags: [String]? // 用于 tag 撤销
        let date: Date
        
        enum UndoType {
            case move       // 撤销: 移回原位
            case copy       // 撤销: 删除副本
            case rename     // 撤销: 改回原名
            case trash      // 撤销: 从废纸篓恢复
            case tag        // 撤销: 移除标签
            case compress   // 撤销: 删除压缩文件
        }
    }
    
    private let fm = FileManager.default
    
    /// 记录操作
    func record(
        operation: String,
        source: String,
        destination: String? = nil,
        success: Bool = true,
        errorMessage: String? = nil,
        undoable: Bool = false,
        undoType: UndoableOperation.UndoType? = nil,
        sourceURL: URL? = nil,
        destURL: URL? = nil,
        originalName: String? = nil,
        originalTags: [String]? = nil
    ) {
        let entry = HistoryEntry(
            date: Date(),
            operation: operation,
            source: source,
            destination: destination,
            success: success,
            errorMessage: errorMessage,
            undoable: undoable
        )
        entries.append(entry)
        
        if entries.count > 1000 {
            entries = Array(entries.suffix(1000))
        }
        
        if undoable, let type = undoType, let source = sourceURL {
            let undo = UndoableOperation(
                type: type,
                sourceURL: source,
                destinationURL: destURL,
                originalName: originalName,
                originalTags: originalTags,
                date: Date()
            )
            undoStack.append(undo)
            
            if undoStack.count > 50 {
                undoStack.removeFirst()
            }
        }
    }
    
    /// 撤销最近一个操作
    func undo() -> Bool {
        guard let last = undoStack.last else { return false }
        
        do {
            switch last.type {
            case .move:
                if let dest = last.destinationURL {
                    // 确保源目录存在
                    let sourceDir = last.sourceURL.deletingLastPathComponent()
                    if !fm.fileExists(atPath: sourceDir.path) {
                        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
                    }
                    try fm.moveItem(at: dest, to: last.sourceURL)
                }
                
            case .copy:
                if let dest = last.destinationURL {
                    try fm.removeItem(at: dest)
                }
                
            case .rename:
                if let dest = last.destinationURL {
                    try fm.moveItem(at: dest, to: last.sourceURL)
                }
                
            case .trash:
                // 从废纸篓恢复：使用 NSWorkspace 的 recover 方法
                // macOS 废纸篓路径: ~/.Trash/
                // 尝试从 Trash 中移回原位
                if let dest = last.destinationURL {
                    let trashPath = dest.path
                    if fm.fileExists(atPath: trashPath) {
                        try fm.moveItem(at: dest, to: last.sourceURL)
                    }
                }
                
            case .tag:
                // 移除之前添加的标签
                if let tags = last.originalTags, let dest = last.destinationURL {
                    var url = dest
                    var currentTags = (try? url.resourceValues(forKeys: [.tagNamesKey])).flatMap { $0.tagNames ?? [] } ?? []
                    // 移除 undo 时记录的 tags (这里 originalTags 存的是被添加的 tags)
                    for tag in tags {
                        currentTags.removeAll { $0 == tag }
                    }
                    var vals = URLResourceValues()
                    vals.tagNames = currentTags.isEmpty ? nil : currentTags
                    try url.setResourceValues(vals)
                }
                
            case .compress:
                if let dest = last.destinationURL {
                    try fm.removeItem(at: dest)
                }
            }
            
            undoStack.removeLast()
            record(operation: "撤销", source: last.sourceURL.path, destination: nil, success: true)
            return true
        } catch {
            record(operation: "撤销失败", source: last.sourceURL.path, success: false, errorMessage: error.localizedDescription)
            return false
        }
    }
    
    func clearHistory() { entries.removeAll() }
    func clearUndoStack() { undoStack.removeAll() }
    var canUndo: Bool { !undoStack.isEmpty }
    
    func recent(_ count: Int = 20) -> [HistoryEntry] {
        Array(entries.suffix(count).reversed())
    }
    
    var todayStats: (total: Int, success: Int, failed: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = entries.filter { $0.date >= today }
        return (
            total: todayEntries.count,
            success: todayEntries.filter(\.success).count,
            failed: todayEntries.filter { !$0.success }.count
        )
    }
}
