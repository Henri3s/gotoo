import Foundation
import Observation

/// 技能执行引擎 — 统一处理 AI 技能和脚本技能
@Observable
@MainActor
final class SkillEngine {
    private let aiEngine = AIEngine()
    private let fileEngine = FileEngine()
    
    /// 是否需要确认 Shell 脚本执行
    var pendingShellApproval: (skill: FileSkill, files: [FileItem], scriptPreview: String)?
    
    var confirmShellSkills: Bool {
        get { UserDefaults.standard.bool(forKey: "confirm_shell_skills") }
        set { UserDefaults.standard.set(newValue, forKey: "confirm_shell_skills") }
    }
    
    struct SkillExecution {
        let id = UUID()
        let skill: FileSkill
        let files: [FileItem]
        let directory: URL
        var result: SkillResult?
        var isExecuting = false
    }
    
    enum SkillResult {
        case success(String)
        case plan(AIActionPlan)
        case failure(String)
    }
    
    // MARK: - Shared DateFormatter
    
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    /// 执行技能
    func execute(
        skill: FileSkill,
        files: [FileItem],
        in directory: URL,
        llmConfig: (baseURL: String, apiKey: String, model: String),
        customPrompt: String? = nil
    ) async throws -> SkillResult {
        switch skill.type {
        case "ai":
            return try await executeAISkill(
                skill: skill,
                files: files,
                in: directory,
                llmConfig: llmConfig,
                customPrompt: customPrompt
            )
        case "shell":
            // 安全检查：如果需要确认，挂起等待用户批准
            if confirmShellSkills {
                let preview = previewScript(skill: skill, file: files.first)
                pendingShellApproval = (skill: skill, files: files, scriptPreview: preview)
                return .success("⚠️ 等待确认执行 Shell 脚本...")
            }
            return try executeShellSkill(skill: skill, files: files)
        case "preset":
            return try await executeAISkill(
                skill: skill,
                files: files,
                in: directory,
                llmConfig: llmConfig,
                customPrompt: customPrompt
            )
        default:
            return .failure("未知的技能类型: \(skill.type)")
        }
    }
    
    /// 用户确认执行 Shell 脚本
    func confirmShellExecution() throws -> SkillResult {
        guard let pending = pendingShellApproval else {
            return .failure("没有待执行的脚本")
        }
        pendingShellApproval = nil
        return try executeShellSkill(skill: pending.skill, files: pending.files)
    }
    
    /// 用户拒绝执行
    func rejectShellExecution() {
        pendingShellApproval = nil
    }
    
    // MARK: - Script Preview
    
    private func previewScript(skill: FileSkill, file: FileItem?) -> String {
        var script = skill.scriptText
        if let file = file {
            script = script.replacingOccurrences(of: "$FILE_PATH", with: file.url.path)
            script = script.replacingOccurrences(of: "$FILE_NAME", with: file.name)
            script = script.replacingOccurrences(of: "$FILE_DIR", with: file.url.deletingLastPathComponent().path)
            script = script.replacingOccurrences(of: "$FILE_EXT", with: file.fileExtension)
        }
        return script
    }
    
    // MARK: - AI Skill
    
    private func executeAISkill(
        skill: FileSkill,
        files: [FileItem],
        in directory: URL,
        llmConfig: (baseURL: String, apiKey: String, model: String),
        customPrompt: String?
    ) async throws -> SkillResult {
        let fileContext = files.map { file -> String in
            var info = "\(file.name)"
            if !file.isDirectory {
                info += " | \(file.formattedSize)"
                if let date = file.modificationDate {
                    info += " | \(Self.dateFormatter.string(from: date))"
                }
            }
            return info
        }.joined(separator: "\n")
        
        let prompt = customPrompt ?? skill.promptText
        
        let message = """
        技能: \(skill.name)
        目标目录: \(directory.path)
        
        文件列表:
        \(fileContext)
        
        \(prompt)
        """
        
        let result = try await aiEngine.chat(
            message: message,
            context: fileContext,
            baseURL: llmConfig.baseURL,
            apiKey: llmConfig.apiKey,
            model: llmConfig.model
        )
        
        if let plan = aiEngine.parseActionPlan(from: result) {
            return .plan(plan)
        }
        
        return .success(result)
    }
    
    // MARK: - Shell Skill
    
    private func executeShellSkill(skill: FileSkill, files: [FileItem]) throws -> SkillResult {
        var outputs: [String] = []
        
        for file in files {
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            
            var script = skill.scriptText
            script = script.replacingOccurrences(of: "$FILE_PATH", with: file.url.path)
            script = script.replacingOccurrences(of: "$FILE_NAME", with: file.name)
            script = script.replacingOccurrences(of: "$FILE_DIR", with: file.url.deletingLastPathComponent().path)
            script = script.replacingOccurrences(of: "$FILE_EXT", with: file.fileExtension)
            
            process.arguments = ["-c", script]
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                outputs.append("OK: \(file.name) — \(output)")
            } else {
                outputs.append("失败: \(file.name) — exit code \(process.terminationStatus): \(output)")
            }
        }
        
        let hasFailure = outputs.contains { $0.hasPrefix("失败") }
        if hasFailure {
            return .failure(outputs.joined(separator: "\n"))
        }
        return .success(outputs.joined(separator: "\n"))
    }
}
