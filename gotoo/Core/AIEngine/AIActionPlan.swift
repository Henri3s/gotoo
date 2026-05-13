import Foundation

/// AI 生成的文件操作计划，供用户确认后执行
struct AIActionPlan: Identifiable {
    let id = UUID()
    let operations: [FileOperation]
    let explanation: String
    
    struct FileOperation: Identifiable {
        let id = UUID()
        let source: String
        let action: ActionKind
        let destination: String?
        let tag: String?
        
        enum ActionKind: String {
            case move = "移动"
            case copy = "复制"
            case rename = "重命名"
            case trash = "删除"
            case createFolder = "创建文件夹"
            case addTag = "添加标签"
            case compress = "压缩"
            case notify = "通知"
        }
        
        init(source: String, action: ActionKind, destination: String? = nil, tag: String? = nil) {
            self.source = source
            self.action = action
            self.destination = destination
            self.tag = tag
        }
        
        var displayText: String {
            switch action {
            case .move: return "\(action.rawValue) \(source) → \(destination ?? "")"
            case .copy: return "\(action.rawValue) \(source) → \(destination ?? "")"
            case .rename: return "\(action.rawValue) \(source) → \(destination ?? "")"
            case .trash: return "\(action.rawValue) \(source)"
            case .createFolder: return "\(action.rawValue) \(destination ?? "")"
            case .addTag: return "\(action.rawValue) '\(tag ?? destination ?? "")' → \(source)"
            case .compress: return "\(action.rawValue) \(source)"
            case .notify: return "\(action.rawValue) \(destination ?? source)"
            }
        }
    }
    
    /// 操作统计
    var stats: (moves: Int, copies: Int, deletes: Int, others: Int) {
        var moves = 0, copies = 0, deletes = 0, others = 0
        for op in operations {
            switch op.action {
            case .move: moves += 1
            case .copy: copies += 1
            case .trash: deletes += 1
            default: others += 1
            }
        }
        return (moves, copies, deletes, others)
    }
}
