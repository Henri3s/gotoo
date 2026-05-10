import SwiftUI
import SwiftData

@main
struct GotooApp: App {
    @State private var appState = AppState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FileRule.self, LLMSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(appState)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            GotooCommands()
        }
        
        Settings {
            SettingsView()
                .environment(appState)
        }
        
        // 系统托盘
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
        
        Button("打开 Gotoo") {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        
        Button("退出") {
            NSApp.terminate(nil)
        }
    }
}
