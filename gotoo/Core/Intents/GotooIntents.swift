import AppIntents
import SwiftData

// MARK: - Run All Rules Intent

struct RunAllRulesIntent: AppIntent {
    static var title: LocalizedStringResource = "执行所有规则"
    static var description = IntentDescription("立即执行所有启用的自动化规则")
    static var openAppWhenRun = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // 通过 SwiftData Query 获取规则
        let appState = AppState.shared
        let context = try ModelContext(GotooApp.sharedModelContainer)
        let descriptor = FetchDescriptor<FileRule>(predicate: #Predicate<FileRule> { $0.isEnabled })
        let rules = try context.fetch(descriptor)
        
        appState.ruleMonitor.runAllOnce(rules: rules)
        return .result(dialog: "已执行 \(rules.count) 条规则")
    }
}

// MARK: - Toggle AI Panel Intent

struct ToggleAIPanelIntent: AppIntent {
    static var title: LocalizedStringResource = "切换AI面板"
    static var description = IntentDescription("显示或隐藏 AI 助手面板")
    static var openAppWhenRun = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.showAIPanel.toggle()
        let state = AppState.shared.showAIPanel ? "打开" : "关闭"
        return .result(dialog: "AI 面板已\(state)")
    }
}

// MARK: - Organize Downloads Intent

struct OrganizeDownloadsIntent: AppIntent {
    static var title: LocalizedStringResource = "整理下载文件夹"
    static var description = IntentDescription("按文件类型自动归类下载文件夹中的文件")
    static var openAppWhenRun = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let fileEngine = FileEngine()
        let ruleEngine = RuleEngine()
        
        // 创建分类规则
        let categories: [(name: String, exts: Set<String>)] = [
            ("图片", FileCategories.imageExtensions),
            ("视频", FileCategories.videoExtensions),
            ("音频", FileCategories.audioExtensions),
            ("文档", FileCategories.documentExtensions),
            ("压缩包", FileCategories.archiveExtensions),
            ("代码", FileCategories.codeExtensions),
        ]
        
        var movedCount = 0
        let files = (try? fileEngine.contents(of: downloads)) ?? []
        
        for file in files where !file.isDirectory {
            for cat in categories {
                if cat.exts.contains(file.fileExtension.lowercased()) {
                    let destDir = downloads.appendingPathComponent(cat.name)
                    try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                    let dest = destDir.appendingPathComponent(file.name)
                    // 避免覆盖
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.moveItem(at: file.url, to: dest)
                        movedCount += 1
                    }
                    break
                }
            }
        }
        
        // 通知刷新
        NotificationCenter.default.post(name: .fileSystemChanged, object: downloads)
        
        return .result(dialog: "已整理 \(movedCount) 个文件到分类文件夹")
    }
}

// MARK: - App Shortcuts Provider

struct GotooShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunAllRulesIntent(),
            phrases: [
                "用 \(.applicationName) 执行所有规则",
                "用 \(.applicationName) run all rules"
            ],
            shortTitle: "执行规则",
            systemImageName: "gearshape"
        )
        
        AppShortcut(
            intent: ToggleAIPanelIntent(),
            phrases: [
                "用 \(.applicationName) 切换AI面板",
                "用 \(.applicationName) toggle AI panel"
            ],
            shortTitle: "AI面板",
            systemImageName: "sparkles"
        )
        
        AppShortcut(
            intent: OrganizeDownloadsIntent(),
            phrases: [
                "用 \(.applicationName) 整理下载文件夹",
                "用 \(.applicationName) organize downloads"
            ],
            shortTitle: "整理下载",
            systemImageName: "arrow.down.circle"
        )
    }
}
