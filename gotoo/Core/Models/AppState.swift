import SwiftUI
import Observation

@Observable
@MainActor
final class AppState: @unchecked Sendable {
    
    /// 单例 — 供 Commands 等非 View 组件访问
    /// View 中仍用 @Environment(AppState.self) 注入
    static let shared = AppState()
    
    // MARK: - Panel Management
    var paneManager = PaneManager()
    
    // MARK: - Panels
    var showAIPanel = false
    var showRulesPanel = false
    var showSkillPanel = false
    var showFolderConfigPanel = false
    var showHistoryPanel = false
    var showTemplatePanel = false
    
    // MARK: - LLM Configuration
    var llmBaseURL: String {
        didSet { UserDefaults.standard.set(llmBaseURL, forKey: "llm_base_url") }
    }
    
    /// API Key — 优先从 Keychain 读取，回退到 UserDefaults（迁移用）
    var llmAPIKey: String {
        didSet { KeychainStore.save(key: "llm_api_key", value: llmAPIKey) }
    }
    
    var llmModel: String {
        didSet { UserDefaults.standard.set(llmModel, forKey: "llm_model") }
    }
    
    var llmIsConfigured: Bool { !llmAPIKey.isEmpty }
    
    // MARK: - AI
    var isProcessingAI = false
    var aiMessages: [AIMessage] = [] {
        didSet { trimMessages() }
    }
    var conversationHistory: [(role: String, content: String)] = []
    
    // MARK: - Favorites (持久化到 UserDefaults)
    var customFavorites: [(name: String, url: URL)] {
        didSet {
            // 持久化：编码为 [[String: String]] 格式
            let data = customFavorites.map { ["name": $0.name, "path": $0.url.path] }
            UserDefaults.standard.set(data, forKey: "custom_favorites")
        }
    }
    
    // MARK: - Rules
    var ruleMonitor = RuleMonitor()
    var isMonitoringEnabled = false
    
    // MARK: - Skills
    let skillEngine = SkillEngine()
    var selectedSkill: FileSkill?
    
    // MARK: - History
    let operationHistory = OperationHistory()
    
    // MARK: - Folder Config
    var currentFolderConfig: FolderConfig?
    
    // MARK: - Navigation
    var selectedSidebarItem: SidebarItem?
    
    // MARK: - Init (从持久化恢复)
    
    init() {
        // 恢复 LLM 配置
        self.llmBaseURL = UserDefaults.standard.string(forKey: "llm_base_url")
            ?? "https://api.siliconflow.cn/v1"
        self.llmModel = UserDefaults.standard.string(forKey: "llm_model")
            ?? "deepseek-ai/DeepSeek-V4-Flash"
        
        // API Key: Keychain 优先，回退 UserDefaults（一次性迁移）
        if let key = KeychainStore.load(key: "llm_api_key") {
            self.llmAPIKey = key
        } else if let legacy = UserDefaults.standard.string(forKey: "llm_api_key") {
            self.llmAPIKey = legacy
            KeychainStore.save(key: "llm_api_key", value: legacy)
            UserDefaults.standard.removeObject(forKey: "llm_api_key")
        } else {
            self.llmAPIKey = ""
        }
        
        // 恢复收藏夹
        if let data = UserDefaults.standard.array(forKey: "custom_favorites") as? [[String: String]] {
            self.customFavorites = data.compactMap { item in
                guard let name = item["name"], let path = item["path"] else { return nil }
                return (name: name, url: URL(fileURLWithPath: path))
            }
        } else {
            self.customFavorites = []
        }
    }
    
    func toggleMonitoring(rules: [FileRule]) {
        if isMonitoringEnabled {
            ruleMonitor.stopMonitoring()
            isMonitoringEnabled = false
        } else {
            ruleMonitor.startMonitoring(rules: rules)
            isMonitoringEnabled = true
        }
    }
    
    /// 获取当前活动面板的 LLM 配置元组
    var llmConfig: (baseURL: String, apiKey: String, model: String) {
        (llmBaseURL, llmAPIKey, llmModel)
    }
    
    // MARK: - AI Messages 限制
    
    private let maxMessages = 200
    
    private func trimMessages() {
        if aiMessages.count > maxMessages {
            aiMessages = Array(aiMessages.suffix(maxMessages))
        }
    }
}
