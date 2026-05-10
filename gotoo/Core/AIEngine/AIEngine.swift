import Foundation

@Observable
@MainActor
final class AIEngine {
    private let session = URLSession.shared
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let max_tokens: Int
        let temperature: Double
        let tools: [Tool]?
        
        struct Message: Codable {
            let role: String
            let content: String
        }
        
        struct Tool: Codable {
            let type: String
            let function: ToolFunction
        }
        
        struct ToolFunction: Codable {
            let name: String
            let description: String
            let parameters: [String: String]
        }
    }
    
    struct ChatResponse: Codable {
        let choices: [Choice]
        struct Choice: Codable {
            let message: ResponseMessage
        }
        struct ResponseMessage: Codable {
            let content: String?
            let tool_calls: [ToolCall]?
        }
        struct ToolCall: Codable {
            let function: FunctionCall
        }
        struct FunctionCall: Codable {
            let name: String
            let arguments: String
        }
    }
    
    /// 定义文件操作工具供 LLM 调用
    static let fileTools: [ChatRequest.Tool] = [
        .init(type: "function", function: .init(
            name: "move_file",
            description: "将文件移动到目标文件夹",
            parameters: ["type": "object", "properties": "{\"source\":{\"type\":\"string\"},\"destination\":{\"type\":\"string\"}}"]
        )),
        .init(type: "function", function: .init(
            name: "rename_file",
            description: "重命名文件",
            parameters: ["type": "object", "properties": "{\"source\":{\"type\":\"string\"},\"new_name\":{\"type\":\"string\"}}"]
        )),
        .init(type: "function", function: .init(
            name: "delete_file",
            description: "将文件移到废纸篓",
            parameters: ["type": "object", "properties": "{\"path\":{\"type\":\"string\"}}"]
        )),
        .init(type: "function", function: .init(
            name: "list_files",
            description: "列出文件夹中的文件",
            parameters: ["type": "object", "properties": "{\"path\":{\"type\":\"string\"}}"]
        )),
    ]
    
    func send(
        message: String,
        context: String,
        baseURL: String,
        apiKey: String,
        model: String
    ) async throws -> String {
        let url = URL(string: baseURL + "/chat/completions")!
        
        let systemPrompt = """
        你是 Gotoo 文件管理器的 AI 助手。你可以帮助用户整理文件。
        当前工作目录内容：
        \(context)
        
        用户会请你执行文件操作。你可以使用以下工具：
        - move_file: 移动文件 (参数: source, destination)
        - rename_file: 重命名文件 (参数: source, new_name)  
        - delete_file: 删除文件 (参数: path)
        - list_files: 列出文件夹内容 (参数: path)
        
        请分析用户需求，给出操作建议。如果需要执行文件操作，请明确说明操作计划等待用户确认。
        用中文回复。
        """
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: message),
            ],
            max_tokens: 4096,
            temperature: 0.3,
            tools: nil  // 先不用 function calling，纯对话模式
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        return response.choices.first?.message.content ?? "无响应"
    }
}
