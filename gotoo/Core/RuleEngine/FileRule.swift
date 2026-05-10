import Foundation
import SwiftData

@Model
final class FileRule {
    var name: String
    var isEnabled: Bool
    var watchPath: String
    var conditionData: Data    // JSON encoded [RuleCondition]
    var actionData: Data       // JSON encoded [RuleAction]
    
    init(name: String, isEnabled: Bool = true, watchPath: String, conditions: [RuleCondition] = [], actions: [RuleAction] = []) {
        self.name = name
        self.isEnabled = isEnabled
        self.watchPath = watchPath
        self.conditionData = (try? JSONEncoder().encode(conditions)) ?? Data()
        self.actionData = (try? JSONEncoder().encode(actions)) ?? Data()
    }
    
    var conditions: [RuleCondition] {
        get { (try? JSONDecoder().decode([RuleCondition].self, from: conditionData)) ?? [] }
        set { conditionData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    
    var actions: [RuleAction] {
        get { (try? JSONDecoder().decode([RuleAction].self, from: actionData)) ?? [] }
        set { actionData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    
    func matches(file: FileItem) -> Bool {
        guard isEnabled else { return false }
        guard file.url.path.hasPrefix(watchPath) else { return false }
        return conditions.allSatisfy { $0.matches(file: file) }
    }
}

struct RuleCondition: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case extensionMatch = "扩展名匹配"
        case nameContains = "名称包含"
        case nameRegex = "名称正则"
        case sizeGreaterThan = "大小大于(字节)"
        case sizeLessThan = "大小小于(字节)"
        case olderThanDays = "早于(天)"
        case newerThanDays = "晚于(天)"
    }
    var kind: Kind
    var value: String
    
    func matches(file: FileItem) -> Bool {
        switch kind {
        case .extensionMatch: return file.fileExtension == value.lowercased()
        case .nameContains: return file.name.localizedCaseInsensitiveContains(value)
        case .nameRegex:
            guard let r = try? NSRegularExpression(pattern: value, options: .caseInsensitive) else { return false }
            return r.firstMatch(in: file.name, range: NSRange(file.name.startIndex..., in: file.name)) != nil
        case .sizeGreaterThan: return file.size > (Int64(value) ?? 0)
        case .sizeLessThan: return file.size < (Int64(value) ?? .max)
        case .olderThanDays:
            guard let d = file.modificationDate, let days = Double(value) else { return false }
            return Date().timeIntervalSince(d) > days * 86400
        case .newerThanDays:
            guard let d = file.modificationDate, let days = Double(value) else { return false }
            return Date().timeIntervalSince(d) < days * 86400
        }
    }
}

struct RuleAction: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case moveTo = "移动到"
        case copyTo = "复制到"
        case rename = "重命名"
        case trash = "移到废纸篓"
        case reveal = "在 Finder 中显示"
    }
    var kind: Kind
    var parameter: String  // 目标路径或新名称
}
