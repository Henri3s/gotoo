import Foundation
import AppKit
import SwiftData

@Model
final class FileRule {
    var name: String
    var isEnabled: Bool
    var watchPath: String
    var conditionData: Data    // JSON encoded [RuleCondition]
    var actionData: Data       // JSON encoded [RuleAction]
    var conditionLogic: String // "all" (AND) or "any" (OR)
    var isRecursive: Bool      // 是否递归子文件夹
    var color: String          // 规则颜色标记 (hex)
    var sortOrder: Int         // 规则排序
    var runMode: String        // "auto" 自动运行, "manual" 仅手动, "confirm" 需确认
    var scheduleData: Data?    // JSON encoded ScheduleConfig?
    var descriptionText: String // 规则描述
    var lastRunDate: Date?     // 上次运行时间
    var runCount: Int          // 运行次数
    var createdAt: Date        // 创建时间
    
    init(name: String, isEnabled: Bool = true, watchPath: String, conditions: [RuleCondition] = [], actions: [RuleAction] = []) {
        self.name = name
        self.isEnabled = isEnabled
        self.watchPath = watchPath
        self.conditionData = (try? JSONEncoder().encode(conditions)) ?? Data()
        self.actionData = (try? JSONEncoder().encode(actions)) ?? Data()
        self.conditionLogic = "all"
        self.isRecursive = false
        self.color = ""
        self.sortOrder = 0
        self.runMode = "auto"
        self.scheduleData = nil
        self.descriptionText = ""
        self.lastRunDate = nil
        self.runCount = 0
        self.createdAt = Date()
    }
    
    var conditions: [RuleCondition] {
        get { (try? JSONDecoder().decode([RuleCondition].self, from: conditionData)) ?? [] }
        set { conditionData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    
    var actions: [RuleAction] {
        get { (try? JSONDecoder().decode([RuleAction].self, from: actionData)) ?? [] }
        set { actionData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    
    var schedule: ScheduleConfig? {
        get {
            guard let data = scheduleData else { return nil }
            return try? JSONDecoder().decode(ScheduleConfig.self, from: data)
        }
        set { scheduleData = try? JSONEncoder().encode(newValue) }
    }
    
    /// 匹配逻辑：all = AND, any = OR
    func matches(file: FileItem) -> Bool {
        guard isEnabled else { return false }
        guard file.url.path.hasPrefix(watchPath) else { return false }
        
        let conds = conditions
        if conds.isEmpty { return true }
        
        switch conditionLogic {
        case "any":
            return conds.contains { $0.matches(file: file) }
        default: // "all"
            return conds.allSatisfy { $0.matches(file: file) }
        }
    }
}

// MARK: - Schedule Configuration

struct ScheduleConfig: Codable, Equatable, @unchecked Sendable {
    var interval: Int         // 间隔（分钟）
    var startTime: String?    // 开始时间 HH:mm
    var endTime: String?      // 结束时间 HH:mm
    var daysOfWeek: [Int]?    // 1=周一...7=周日, nil = 每天
}

// MARK: - Rule Condition (增强版)

struct RuleCondition: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        // 文件名
        case extensionMatch = "扩展名匹配"
        case nameContains = "名称包含"
        case nameRegex = "名称正则"
        case nameStartsWith = "名称前缀"
        case nameEndsWith = "名称后缀"
        case nameEquals = "名称等于"
        
        // 大小
        case sizeGreaterThan = "大小大于"
        case sizeLessThan = "大小小于"
        case sizeBetween = "大小范围"
        
        // 时间
        case olderThanDays = "早于(天)"
        case newerThanDays = "晚于(天)"
        case modifiedToday = "今天修改"
        case modifiedThisWeek = "本周修改"
        case modifiedThisMonth = "本月修改"
        case createdToday = "今天创建"
        case createdThisWeek = "本周创建"
        case createdThisMonth = "本月创建"
        
        // 类型
        case isImage = "是图片"
        case isVideo = "是视频"
        case isAudio = "是音频"
        case isDocument = "是文档"
        case isArchive = "是压缩包"
        case isCode = "是代码文件"
        case isPDF = "是PDF"
        
        // 属性
        case isHidden = "是隐藏文件"
        case hasTag = "有标签"
        case hasColor = "有颜色标记"
        
        // 内容
        case contentContains = "内容包含"
    }
    
    var kind: Kind
    var value: String
    var value2: String?  // 用于范围条件 (如大小范围)
    var isNegated: Bool   // 条件取反
    
    init(kind: Kind, value: String, value2: String? = nil, isNegated: Bool = false) {
        self.kind = kind
        self.value = value
        self.value2 = value2
        self.isNegated = isNegated
    }
    
    func matches(file: FileItem) -> Bool {
        let result: Bool
        switch kind {
        // 文件名
        case .extensionMatch:
            result = file.fileExtension == value.lowercased()
        case .nameContains:
            result = file.name.localizedCaseInsensitiveContains(value)
        case .nameRegex:
            guard let r = try? NSRegularExpression(pattern: value, options: .caseInsensitive) else { return false }
            result = r.firstMatch(in: file.name, range: NSRange(file.name.startIndex..., in: file.name)) != nil
        case .nameStartsWith:
            result = file.name.lowercased().hasPrefix(value.lowercased())
        case .nameEndsWith:
            result = file.name.lowercased().hasSuffix(value.lowercased())
        case .nameEquals:
            result = file.name == value
            
        // 大小
        case .sizeGreaterThan:
            let bytes = parseSizeToBytes(value)
            result = file.size > bytes
        case .sizeLessThan:
            let bytes = parseSizeToBytes(value)
            result = file.size < bytes
        case .sizeBetween:
            let minBytes = parseSizeToBytes(value)
            let maxBytes = parseSizeToBytes(value2 ?? "")
            result = file.size >= minBytes && file.size <= maxBytes
            
        // 时间
        case .olderThanDays:
            guard let d = file.modificationDate, let days = Double(value) else { return false }
            result = Date().timeIntervalSince(d) > days * 86400
        case .newerThanDays:
            guard let d = file.modificationDate, let days = Double(value) else { return false }
            result = Date().timeIntervalSince(d) < days * 86400
        case .modifiedToday:
            guard let d = file.modificationDate else { return false }
            result = Calendar.current.isDateInToday(d)
        case .modifiedThisWeek:
            guard let d = file.modificationDate else { return false }
            result = Calendar.current.isDate(d, equalTo: Date(), toGranularity: .weekOfYear)
        case .modifiedThisMonth:
            guard let d = file.modificationDate else { return false }
            result = Calendar.current.isDate(d, equalTo: Date(), toGranularity: .month)
        case .createdToday:
            guard let d = file.creationDate else { return false }
            result = Calendar.current.isDateInToday(d)
        case .createdThisWeek:
            guard let d = file.creationDate else { return false }
            result = Calendar.current.isDate(d, equalTo: Date(), toGranularity: .weekOfYear)
        case .createdThisMonth:
            guard let d = file.creationDate else { return false }
            result = Calendar.current.isDate(d, equalTo: Date(), toGranularity: .month)
            
        // 类型
        case .isImage:
            result = FileCategories.imageExtensions.contains(file.fileExtension)
        case .isVideo:
            result = FileCategories.videoExtensions.contains(file.fileExtension)
        case .isAudio:
            result = FileCategories.audioExtensions.contains(file.fileExtension)
        case .isDocument:
            result = FileCategories.documentExtensions.contains(file.fileExtension)
        case .isArchive:
            result = FileCategories.archiveExtensions.contains(file.fileExtension)
        case .isCode:
            result = FileCategories.codeExtensions.contains(file.fileExtension)
        case .isPDF:
            result = file.fileExtension == "pdf"
            
        // 属性
        case .isHidden:
            result = file.url.lastPathComponent.hasPrefix(".")
        case .hasTag:
            result = file.tags.contains(where: { $0.name.localizedCaseInsensitiveContains(value) })
        case .hasColor:
            result = file.labelColor != .none
            
        // 内容
        case .contentContains:
            result = fileContainsText(file: file, query: value)
        }
        
        return isNegated ? !result : result
    }
    
    /// 解析人类可读的大小字符串为字节数
    /// 支持: "100", "1KB", "5MB", "2GB", "1.5TB"
    private func parseSizeToBytes(_ sizeStr: String) -> Int64 {
        let str = sizeStr.trimmingCharacters(in: .whitespaces).uppercased()
        guard !str.isEmpty else { return 0 }
        
        let multipliers: [(suffix: String, factor: Int64)] = [
            ("TB", 1_099_511_627_776),
            ("GB", 1_073_741_824),
            ("MB", 1_048_576),
            ("KB", 1024),
        ]
        
        for (suffix, factor) in multipliers {
            if str.hasSuffix(suffix) {
                let numStr = str.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
                if let num = Double(numStr) { return Int64(num * Double(factor)) }
            }
        }
        
        return Int64(str) ?? 0
    }
    
    /// 检查文件内容是否包含文本（仅文本文件，限制读取量）
    private func fileContainsText(file: FileItem, query: String) -> Bool {
        guard file.size < 10_000_000 else { return false } // 跳过大于10MB的文件
        guard let data = try? FileHandle(forReadingFrom: file.url).read(upToCount: 65536),
              let content = String(data: data, encoding: .utf8) else { return false }
        return content.localizedCaseInsensitiveContains(query)
    }
}

// MARK: - Rule Action (增强版)

struct RuleAction: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case moveTo = "移动到"
        case copyTo = "复制到"
        case rename = "重命名"
        case trash = "移到废纸篓"
        case reveal = "在Finder中显示"
        case addTag = "添加标签"
        case removeTag = "移除标签"
        case setColor = "设置颜色"
        case moveToDatedSubfolder = "移到日期子文件夹"
        case runShellScript = "运行脚本"
        case runAISkill = "运行AI技能"
        case compress = "压缩"
        case notify = "发送通知"
        case sortBy = "按类型归类"
        case makeAlias = "创建别名"
    }
    
    var kind: Kind
    var parameter: String
    var parameter2: String?  // 第二参数
    
    init(kind: Kind, parameter: String = "", parameter2: String? = nil) {
        self.kind = kind
        self.parameter = parameter
        self.parameter2 = parameter2
    }
}

// MARK: - File Label Color (扩展 init(fromLabelIndex:) — 基础定义在 FileEngine.swift)

extension FileLabelColor {
    init(fromLabelIndex index: Int?) {
        switch index {
        case 1: self = .red
        case 2: self = .orange
        case 3: self = .yellow
        case 4: self = .green
        case 5: self = .blue
        case 6: self = .purple
        case 7: self = .gray
        default: self = .none
        }
    }
}
