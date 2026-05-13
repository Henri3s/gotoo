import Foundation
import SwiftData

/// 文件夹级别的自定义配置 — 每个文件夹可以绑定独立的提示词和规则
@Model
final class FolderConfig {
    var folderPath: String
    var customPrompt: String         // 该文件夹的 AI 提示词
    var autoPrompt: String           // 自动执行的提示词（文件变更时触发）
    var isAutoEnabled: Bool          // 是否启用自动 AI 处理
    var linkedSkillNames: Data?      // JSON encoded [String] 关联的技能名
    var preferredModel: String?      // 该文件夹偏好的模型
    var maxFileSize: Int64           // 最大处理文件大小限制
    var excludePatterns: Data?       // JSON encoded [String] 排除模式
    var customActions: Data?         // JSON encoded [QuickAction] 自定义快捷操作
    var createdAt: Date
    var updatedAt: Date
    
    init(
        folderPath: String,
        customPrompt: String = "",
        autoPrompt: String = "",
        isAutoEnabled: Bool = false,
        maxFileSize: Int64 = 100_000_000 // 100MB 默认
    ) {
        self.folderPath = folderPath
        self.customPrompt = customPrompt
        self.autoPrompt = autoPrompt
        self.isAutoEnabled = isAutoEnabled
        self.maxFileSize = maxFileSize
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var linkedSkills: [String] {
        get {
            guard let data = linkedSkillNames else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set { linkedSkillNames = try? JSONEncoder().encode(newValue) }
    }
    
    var excludes: [String] {
        get {
            guard let data = excludePatterns else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set { excludePatterns = try? JSONEncoder().encode(newValue) }
    }
    
    var quickActions: [QuickAction] {
        get {
            guard let data = customActions else { return [] }
            return (try? JSONDecoder().decode([QuickAction].self, from: data)) ?? []
        }
        set { customActions = try? JSONEncoder().encode(newValue) }
    }
    
    /// 判断文件是否应该被处理
    func shouldProcess(file: FileItem) -> Bool {
        // 大小限制
        if file.size > maxFileSize { return false }
        
        // 排除模式
        for pattern in excludes {
            if file.name.localizedCaseInsensitiveContains(pattern) { return false }
            if file.fileExtension == pattern.lowercased() { return false }
        }
        
        return true
    }
}

/// 快捷操作 — 用户为特定文件夹定义的快速文件操作
struct QuickAction: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String       // SF Symbol
    var prompt: String     // 操作的提示词
    var isDestructive: Bool // 是否是破坏性操作
    
    init(name: String, icon: String = "bolt", prompt: String, isDestructive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.prompt = prompt
        self.isDestructive = isDestructive
    }
}
