import Foundation
import AppKit
@preconcurrency import UserNotifications
import Observation

@Observable
@MainActor
final class RuleEngine {
    private let fileEngine = FileEngine()
    
    /// 对文件夹中的所有文件运行所有匹配的规则（支持递归）
    func apply(rules: [FileRule], toDirectory url: URL) throws -> [(FileRule, FileItem)] {
        var matched: [(FileRule, FileItem)] = []
        
        for rule in rules where rule.isEnabled {
            let files: [FileItem]
            if rule.isRecursive {
                files = try fileEngine.contentsRecursiveSync(of: url)
            } else {
                files = try fileEngine.contents(of: url)
            }
            
            for file in files where !file.isDirectory {
                if rule.matches(file: file) {
                    matched.append((rule, file))
                }
            }
        }
        return matched
    }
    
    /// 执行单条规则动作
    func execute(action: RuleAction, on file: FileItem) throws -> String {
        switch action.kind {
        case .moveTo:
            let dest = URL(fileURLWithPath: action.parameter)
            try fileEngine.move(from: file.url, to: dest)
            return "OK: 移动 \(file.name) → \(action.parameter)"
            
        case .copyTo:
            let dest = URL(fileURLWithPath: action.parameter)
            try fileEngine.copy(from: file.url, to: dest)
            return "OK: 复制 \(file.name) → \(action.parameter)"
            
        case .rename:
            let newName = applyRenameTemplate(action.parameter, to: file)
            _ = try fileEngine.rename(file.url, to: newName)
            return "OK: 重命名 \(file.name) → \(newName)"
            
        case .trash:
            _ = try fileEngine.trash(file.url)
            return "OK: 删除 \(file.name)"
            
        case .reveal:
            NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
            return "OK: 显示 \(file.name)"
            
        case .addTag:
            try addTag(action.parameter, to: file.url)
            return "OK: 添加标签 '\(action.parameter)' 到 \(file.name)"
            
        case .removeTag:
            try removeTag(action.parameter, from: file.url)
            return "OK: 移除标签 '\(action.parameter)' 从 \(file.name)"
            
        case .setColor:
            try setFinderLabel(color: action.parameter, for: file.url)
            return "OK: 设置颜色 \(action.parameter) 到 \(file.name)"
            
        case .moveToDatedSubfolder:
            let dateFormat = action.parameter.isEmpty ? "yyyy-MM-dd" : action.parameter
            let parent = action.parameter2 ?? file.url.deletingLastPathComponent().path
            try moveToDatedSubfolder(file: file, parentPath: parent, dateFormat: dateFormat)
            return "OK: 移动 \(file.name) 到日期子文件夹"
            
        case .runShellScript:
            let output = try runShellScript(action.parameter, on: file)
            return "OK: 脚本执行完成 \(file.name)\n\(output)"
            
        case .runAISkill:
            // AI Skill 将在 v0.3 中实现
            return "OK: AI技能执行 \(file.name) (将在下个版本实现)"
            
        case .compress:
            try compressFile(file)
            return "OK: 压缩 \(file.name)"
            
        case .notify:
            sendNotification(title: "Gotoo 规则", body: action.parameter.isEmpty ? "处理了 \(file.name)" : action.parameter)
            return "OK: 发送通知"
            
        case .sortBy:
            try sortByType(file: file, basePath: action.parameter)
            return "OK: 按类型归类 \(file.name)"
            
        case .makeAlias:
            let aliasPath = action.parameter.isEmpty 
                ? file.url.deletingLastPathComponent().path 
                : action.parameter
            try makeAlias(of: file.url, at: aliasPath)
            return "OK: 创建别名 \(file.name)"
        }
    }
    
    // MARK: - Rename Template
    
    private func applyRenameTemplate(_ template: String, to file: FileItem) -> String {
        var result = template
        let ext = file.fileExtension
        let nameWithoutExt = file.url.deletingPathExtension().lastPathComponent
        let now = Date()
        let df = DateFormatter()
        
        // {name} 原始文件名（无扩展名）
        result = result.replacingOccurrences(of: "{name}", with: nameWithoutExt)
        
        // {ext} 扩展名
        result = result.replacingOccurrences(of: "{ext}", with: ext)
        
        // {date} 日期
        df.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{date}", with: df.string(from: now))
        
        // {time} 时间
        df.dateFormat = "HH-mm-ss"
        result = result.replacingOccurrences(of: "{time}", with: df.string(from: now))
        
        // {datetime} 日期时间
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        result = result.replacingOccurrences(of: "{datetime}", with: df.string(from: now))
        
        // {parent} 父文件夹名
        let parent = file.url.deletingLastPathComponent().lastPathComponent
        result = result.replacingOccurrences(of: "{parent}", with: parent)
        
        // {size} 文件大小
        result = result.replacingOccurrences(of: "{size}", with: file.formattedSize)
        
        // {counter} 计数器 (处理重名)
        if result.contains("{counter}") {
            var counter = 1
            var testPath = result.replacingOccurrences(of: "{counter}", with: "\(counter)")
            while FileManager.default.fileExists(atPath: file.url.deletingLastPathComponent().appendingPathComponent(testPath).path) {
                counter += 1
                testPath = result.replacingOccurrences(of: "{counter}", with: "\(counter)")
            }
            result = testPath
        }
        
        return result
    }
    
    // MARK: - Tag Operations
    
    private func addTag(_ tag: String, to url: URL) throws {
        var url = url
        var currentTags = (try? url.resourceValues(forKeys: [.tagNamesKey])).flatMap { $0.tagNames ?? [] } ?? []
        if !currentTags.contains(tag) {
            currentTags.append(tag)
            var vals = URLResourceValues()
            vals.tagNames = currentTags
            try url.setResourceValues(vals)
        }
    }
    
    private func removeTag(_ tag: String, from url: URL) throws {
        var url = url
        var currentTags = (try? url.resourceValues(forKeys: [.tagNamesKey])).flatMap { $0.tagNames ?? [] } ?? []
        currentTags.removeAll { $0 == tag }
        var vals = URLResourceValues()
        vals.tagNames = currentTags
        try url.setResourceValues(vals)
    }
    
    // MARK: - Finder Label
    
    private func setFinderLabel(color: String, for url: URL) throws {
        let colorMap: [String: Int] = [
            "红色": 1, "橙色": 2, "黄色": 3, "绿色": 4, "蓝色": 5, "紫色": 6, "灰色": 7,
            "red": 1, "orange_en": 2, "yellow": 3, "green": 4, "blue": 5, "purple": 6, "gray": 7,
        ]
        let idx = colorMap[color] ?? 0
        // Use xattr to set Finder label
        if idx > 0 {
            try setFinderInfoLabel(url: url, labelIndex: idx)
        }
    }
    
    private func setFinderInfoLabel(url: URL, labelIndex: Int) throws {
        // Write label via extended attribute
        let xattrName = "com.apple.FinderInfo"
        var finderInfo = [UInt8](repeating: 0, count: 32)
        // Read existing if any
        getxattr(url.path, xattrName, &finderInfo, 32, 0, XATTR_NOFOLLOW)
        finderInfo[9] = UInt8(labelIndex)
        setxattr(url.path, xattrName, &finderInfo, 32, 0, XATTR_NOFOLLOW)
    }
    
    // MARK: - Dated Subfolder
    
    private func moveToDatedSubfolder(file: FileItem, parentPath: String, dateFormat: String) throws {
        let df = DateFormatter()
        df.dateFormat = dateFormat
        let dateStr = df.string(from: file.modificationDate ?? Date())
        
        let subfolder = URL(fileURLWithPath: parentPath).appendingPathComponent(dateStr)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try fileEngine.move(from: file.url, to: subfolder)
    }
    
    // MARK: - Shell Script
    
    @discardableResult
    private func runShellScript(_ script: String, on file: FileItem) throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.standardOutput = pipe
        process.environment = [
            "FILE_PATH": file.url.path,
            "FILE_NAME": file.name,
            "FILE_DIR": file.url.deletingLastPathComponent().path,
            "FILE_EXT": file.fileExtension,
            "FILE_SIZE": "\(file.size)",
        ]
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - Compress
    
    private func compressFile(_ file: FileItem) throws {
        let dest = file.url.deletingPathExtension().appendingPathExtension("zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", file.url.path, dest.path]
        try process.run()
        process.waitUntilExit()
    }
    
    // MARK: - Sort By Type
    
    private func sortByType(file: FileItem, basePath: String) throws {
        let category = file.category
        guard category != .folder && category != .other else { return }
        
        let base = URL(fileURLWithPath: basePath.isEmpty ? file.url.deletingLastPathComponent().path : basePath)
        let categoryFolder = base.appendingPathComponent(category.rawValue)
        try FileManager.default.createDirectory(at: categoryFolder, withIntermediateDirectories: true)
        try fileEngine.move(from: file.url, to: categoryFolder)
    }
    
    // MARK: - Make Alias
    
    private func makeAlias(of original: URL, at destPath: String) throws {
        let dest = URL(fileURLWithPath: destPath)
        let aliasPath = dest.appendingPathComponent(original.deletingPathExtension().lastPathComponent + " Alias")
        // Use FileManager symbolic link as a simple alias
        try FileManager.default.createSymbolicLink(atPath: aliasPath.path, withDestinationPath: original.path)
    }
    
    // MARK: - Notification
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}
