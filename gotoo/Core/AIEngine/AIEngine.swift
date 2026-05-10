import Foundation
import AppKit

@Observable
@MainActor
final class AIEngine {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
    
    // MARK: - API Types
    
    private struct Request: Codable {
        let model: String
        let messages: [Message]
        let max_tokens: Int
        let temperature: Double
        let tools: [ToolDef]?
        let tool_choice: ToolChoice?
        
        struct Message: Codable {
            let role: String
            let content: String
            let tool_calls: [ToolCall]?
            let tool_call_id: String?
        }
        
        struct ToolDef: Codable {
            let type: String
            let function: FuncDef
        }
        
        struct FuncDef: Codable {
            let name: String
            let description: String
            let parameters: String  // JSON string
        }
        
        struct ToolChoice: Codable {
            let type: String
        }
        
        struct ToolCall: Codable {
            let id: String
            let type: String
            let function: FuncCall
        }
        
        struct FuncCall: Codable {
            let name: String
            let arguments: String
        }
    }
    
    private struct Response: Codable {
        let choices: [Choice]
        struct Choice: Codable {
            let message: RespMessage
        }
        struct RespMessage: Codable {
            let content: String?
            let tool_calls: [RespToolCall]?
        }
        struct RespToolCall: Codable {
            let id: String
            let type: String
            let function: RespFuncCall
        }
        struct RespFuncCall: Codable {
            let name: String
            let arguments: String
        }
    }
    
    // MARK: - Tool Definitions
    
    private static let toolDefs: [Request.ToolDef] = [
        .init(type: "function", function: .init(
            name: "organize_files",
            description: "根据用户指令，制定文件整理计划。返回要执行的操作列表。",
            parameters: """
            {
                "type": "object",
                "properties": {
                    "explanation": {"type": "string", "description": "操作说明"},
                    "operations": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source": {"type": "string", "description": "源文件名"},
                                "action": {"type": "string", "enum": ["move", "copy", "rename", "trash", "createFolder"]},
                                "destination": {"type": "string", "description": "目标路径或新名称"}
                            },
                            "required": ["source", "action"]
                        }
                    }
                },
                "required": ["explanation", "operations"]
            }
            """
        ))
    ]
    
    // MARK: - Public API
    
    /// 发送消息并获取 AI 回复（纯对话）
    func chat(
        message: String,
        context: String,
        baseURL: String,
        apiKey: String,
        model: String
    ) async throws -> String {
        let systemPrompt = buildSystemPrompt(context: context)
        let url = URL(string: baseURL + "/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = Request(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt, tool_calls: nil, tool_call_id: nil),
                .init(role: "user", content: message, tool_calls: nil, tool_call_id: nil),
            ],
            max_tokens: 4096,
            temperature: 0.3,
            tools: Self.toolDefs,
            tool_choice: .init(type: "auto")
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        
        // Check for API error
        if let errorResp = try? JSONDecoder().decode(APIError.self, from: data) {
            throw AIError.apiError(errorResp.error.message)
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        // If tool call, parse the organize_files result
        if let toolCall = response.choices.first?.message.tool_calls?.first {
            let args = toolCall.function.arguments
            return args  // Return raw JSON for the caller to parse
        }
        
        return response.choices.first?.message.content ?? "无响应"
    }
    
    /// 解析 AI 返回的操作计划
    func parseActionPlan(from json: String) -> AIActionPlan? {
        guard let data = json.data(using: .utf8) else { return nil }
        
        struct RawPlan: Codable {
            let explanation: String
            let operations: [RawOp]
            struct RawOp: Codable {
                let source: String
                let action: String
                let destination: String?
            }
        }
        
        guard let raw = try? JSONDecoder().decode(RawPlan.self, from: data) else { return nil }
        
        let ops = raw.operations.compactMap { op -> AIActionPlan.FileOperation? in
            guard let kind = AIActionPlan.FileOperation.ActionKind(rawValue: op.action) else { return nil }
            return .init(source: op.source, action: kind, destination: op.destination)
        }
        
        return AIActionPlan(operations: ops, explanation: raw.explanation)
    }
    
    /// 执行确认后的操作计划
    func execute(plan: AIActionPlan, in directory: URL) -> [String] {
        let engine = FileEngine()
        var results: [String] = []
        
        for op in plan.operations {
            let sourceURL = directory.appendingPathComponent(op.source)
            
            do {
                switch op.action {
                case .move:
                    guard let dest = op.destination else { continue }
                    let destURL = URL(fileURLWithPath: dest)
                    try engine.move(from: sourceURL, to: destURL)
                    results.append("OK: 移动 \(op.source)")
                case .copy:
                    guard let dest = op.destination else { continue }
                    let destURL = URL(fileURLWithPath: dest)
                    try engine.copy(from: sourceURL, to: destURL)
                    results.append("OK: 复制 \(op.source)")
                case .rename:
                    guard let newName = op.destination else { continue }
                    _ = try engine.rename(sourceURL, to: newName)
                    results.append("OK: 重命名 \(op.source) → \(newName)")
                case .trash:
                    try engine.trash(sourceURL)
                    results.append("OK: 删除 \(op.source)")
                case .createFolder:
                    guard let name = op.destination else { continue }
                    _ = try engine.createFolder(at: directory, name: name)
                    results.append("OK: 创建文件夹 \(name)")
                }
            } catch {
                results.append("失败: \(op.source) — \(error.localizedDescription)")
            }
        }
        return results
    }
    
    // MARK: - Private
    
    private func buildSystemPrompt(context: String) -> String {
        """
        你是 Gotoo 文件管理器的 AI 助手。用户会请你整理文件。
        
        当前目录的文件列表：
        \(context)
        
        当用户提出文件整理需求时，请调用 organize_files 工具，生成操作计划。
        每个操作包含 source（文件名）、action（move/copy/rename/trash/createFolder）、destination（目标路径或新名称）。
        
        规则：
        1. source 必须是当前目录中实际存在的文件名
        2. destination 对于 move/copy 应该是目标文件夹的绝对路径
        3. destination 对于 rename 应该是新的文件名（不含路径）
        4. 操作前请先说明你的整理思路
        5. 用中文回复
        
        如果用户只是提问或聊天（不涉及文件操作），直接回复文字即可，不要调用工具。
        """
    }
    
    private struct APIError: Codable {
        let error: APIErrorDetail
        struct APIErrorDetail: Codable { let message: String }
    }
    
    enum AIError: LocalizedError {
        case apiError(String)
        case noResponse
        
        var errorDescription: String? {
            switch self {
            case .apiError(let msg): return "API 错误: \(msg)"
            case .noResponse: return "无响应"
            }
        }
    }
}
