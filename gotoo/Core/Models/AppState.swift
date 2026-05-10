import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    var selectedSidebarItem: SidebarItem?
    var selectedFiles: Set<URL> = []
    var currentDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    var searchQuery = ""
    var isProcessingAI = false
    var aiMessages: [AIMessage] = []
    var showAIPanel = false
    var showRulesPanel = false
    
    // LLM
    var llmBaseURL: String = "https://api.siliconflow.cn/v1"
    var llmAPIKey: String = ""
    var llmModel: String = "deepseek-ai/DeepSeek-V4-Flash"
    
    var llmIsConfigured: Bool { !llmAPIKey.isEmpty }
    
    func navigateTo(_ url: URL) {
        currentDirectory = url
        selectedFiles.removeAll()
    }
}
