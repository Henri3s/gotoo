import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    var paneManager = PaneManager()
    var showAIPanel = false
    var showRulesPanel = false
    
    // LLM Config
    var llmBaseURL: String = "https://api.siliconflow.cn/v1"
    var llmAPIKey: String = ""
    var llmModel: String = "deepseek-ai/DeepSeek-V4-Flash"
    var llmIsConfigured: Bool { !llmAPIKey.isEmpty }
    
    // AI
    var isProcessingAI = false
    var aiMessages: [AIMessage] = []
    
    // 自定义收藏夹
    var customFavorites: [(String, URL)] = []
    
    // 全局搜索
    var globalSearchQuery = ""
}
