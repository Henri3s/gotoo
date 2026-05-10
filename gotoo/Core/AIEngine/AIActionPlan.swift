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
        
        enum ActionKind: String {
            case move = "移动"
            case copy = "复制"
            case rename = "重命名"
            case trash = "删除"
            case createFolder = "创建文件夹"
        }
        
        var displayText: String {
            switch action {
            case .move: return "\(action.rawValue) \(source) → \(destination ?? "")"
            case .copy: return "\(action.rawValue) \(source) → \(destination ?? "")"
            case .rename: return "\(action.rawValue) \(source) → \(destination ?? "")"
            case .trash: return "\(action.rawValue) \(source)"
            case .createFolder: return "\(action.rawValue) \(destination ?? "")"
            }
        }
    }
}
