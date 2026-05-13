import SwiftUI
import SwiftData

@main
struct GotooApp: App {
    @State private var appState = AppState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FileRule.self, FileSkill.self, FolderConfig.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 优雅降级：记录错误，使用内存容器让 App 仍能启动
            print("[Gotoo] ModelContainer 创建失败，使用内存模式: \(error)")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(appState)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            GotooCommands()
        }
        
        Settings {
            SettingsView()
                .environment(appState)
        }
        
        MenuBarExtra("Gotoo", systemImage: appState.isMonitoringEnabled ? "folder.badge.gearshape" : "folder") {
            MenuBarExtraContent()
                .environment(appState)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarExtraContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [FileRule]
    
    var body: some View {
        Button(appState.isMonitoringEnabled ? "停止监控" : "开始监控") {
            appState.toggleMonitoring(rules: rules)
        }
        
        Divider()
        
        Button("立即执行所有规则") {
            appState.ruleMonitor.runAllOnce(rules: rules)
        }
        
        Button("打开规则模板") {
            appState.showTemplatePanel = true
            NSApp.activate(ignoringOtherApps: true)
        }
        
        Button("打开技能库") {
            appState.showSkillPanel = true
            NSApp.activate(ignoringOtherApps: true)
        }
        
        Divider()
        
        let recentLogs = appState.ruleMonitor.executionLog.suffix(5)
        if recentLogs.isEmpty {
            Text("暂无执行记录").foregroundStyle(.secondary)
        } else {
            ForEach(Array(recentLogs.reversed()), id: \.id) { entry in
                Text("\(entry.ruleName): \(entry.fileName) → \(entry.action)")
                    .font(.caption)
            }
        }
        
        Divider()
        
        let stats = appState.operationHistory.todayStats
        Text("今日: \(stats.total) 操作, \(stats.success) 成功")
            .font(.caption)
            .foregroundStyle(.secondary)
        
        Divider()
        
        Button("打开 Gotoo") {
            NSApp.activate(ignoringOtherApps: true)
            if let w = NSApp.windows.first(where: { $0.isVisible }) { w.makeKeyAndOrderFront(nil) }
        }
        
        Button("退出 Gotoo") { NSApp.terminate(nil) }
    }
}
