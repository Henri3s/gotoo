import AppIntents

/// App Intents — 支持 Spotlight 和快捷指令

/// 执行所有自动化规则
struct RunAllRulesIntent: AppIntent {
    static var title: LocalizedStringResource = "执行所有规则"
    static var description = IntentDescription("立即执行所有已启用的自动化规则")
    
    func perform() async throws -> some IntentResult {
        // 通过 AppState 单例获取规则并执行
        // 注意：这里需要通过 App 的 shared state 来实现
        return .result(dialog: "已触发执行所有规则")
    }
}

/// 切换 AI 面板
struct ToggleAIPanelIntent: AppIntent {
    static var title: LocalizedStringResource = "切换 AI 面板"
    static var description = IntentDescription("显示或隐藏 AI 文件助手面板")
    
    func perform() async throws -> some IntentResult {
        return .result(dialog: "已切换 AI 面板")
    }
}

/// 整理下载文件夹
struct OrganizeDownloadsIntent: AppIntent {
    static var title: LocalizedStringResource = "整理下载文件夹"
    static var description = IntentDescription("使用 AI 整理下载文件夹中的文件")
    
    func perform() async throws -> some IntentResult {
        return .result(dialog: "已触发下载文件夹整理")
    }
}

/// App Shortcuts — 让用户从 Spotlight 直接触发
struct GotooShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunAllRulesIntent(),
            phrases: [
                "用 \(.applicationName) 执行所有规则",
                "Run all rules in \(.applicationName)"
            ],
            shortTitle: "执行规则",
            systemImageName: "gearshape"
        )
        
        AppShortcut(
            intent: ToggleAIPanelIntent(),
            phrases: [
                "在 \(.applicationName) 中打开 AI",
                "Open AI in \(.applicationName)"
            ],
            shortTitle: "AI 面板",
            systemImageName: "sparkles"
        )
        
        AppShortcut(
            intent: OrganizeDownloadsIntent(),
            phrases: [
                "用 \(.applicationName) 整理下载",
                "Organize downloads with \(.applicationName)"
            ],
            shortTitle: "整理下载",
            systemImageName: "arrow.down.circle"
        )
    }
}
