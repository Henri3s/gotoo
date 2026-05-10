import Foundation
import SwiftData

@Model
final class LLMSettings {
    var baseURL: String
    var apiKey: String
    var model: String
    
    init(baseURL: String = "https://api.siliconflow.cn/v1", apiKey: String = "", model: String = "deepseek-ai/DeepSeek-V4-Flash") {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }
}
