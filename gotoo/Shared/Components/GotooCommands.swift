import SwiftUI
import SwiftData

struct GotooCommands: Commands {
    @Environment(AppState.self) private var appState
    
    var body: some Commands {
        // 文件菜单
        CommandGroup(after: .newItem) {
            Button("新建文件夹") {
                // TODO: 在当前面板创建文件夹
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Divider()
            
            Button("关闭窗口") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        
        // 编辑菜单
        CommandGroup(after: .pasteboard) {
            Button("撤销操作") {
                _ = appState.operationHistory.undo()
            }
            .keyboardShortcut("z", modifiers: [.command])
            
            Divider()
            
            Button("拷贝路径") {
                // TODO: 拷贝选中文件路径
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        
        // 视图菜单
        CommandMenu("视图") {
            Picker("面板布局", selection: Binding(
                get: { appState.paneManager.layout },
                set: { appState.paneManager.setLayout($0) }
            )) {
                Text("单栏").tag(PaneLayout.single)
                Text("双栏").tag(PaneLayout.dual)
                Text("三栏").tag(PaneLayout.triple)
            }
            
            Divider()
            
            Button("切换 AI 面板") {
                appState.showAIPanel.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            
            Button("刷新") {
                // 由 PaneView 内部处理
            }
            .keyboardShortcut("r", modifiers: [.command])
            
            Divider()
            
            Button("切换到下一面板") {
                appState.paneManager.nextPane()
            }
            .keyboardShortcut("\\", modifiers: [.command])
        }
        
        // 工具菜单
        CommandMenu("工具") {
            Button("自动化规则...") {
                appState.showRulesPanel = true
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            
            Button("技能库...") {
                appState.showSkillPanel = true
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            
            Button("规则模板...") {
                appState.showTemplatePanel = true
            }
            
            Divider()
            
            Button("文件夹配置...") {
                appState.showFolderConfigPanel = true
            }
            
            Button("操作历史...") {
                appState.showHistoryPanel = true
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            
            Divider()
            
            Button("立即执行所有规则") {
                // 需要拿到 rules，通过 modelContext query
                // 在 Commands 中无法直接 @Query，通过 notification 传递
                NotificationCenter.default.post(name: .runAllRules, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        
        // 跳转菜单
        CommandMenu("跳转") {
            Button("后退") {
                let parent = appState.paneManager.activePane.currentDirectory.deletingLastPathComponent()
                appState.paneManager.activePane.navigateTo(parent)
            }
            .keyboardShortcut("[", modifiers: [.command])
            
            Button("前进") {
                // TODO: 前进栈
            }
            .keyboardShortcut("]", modifiers: [.command])
            
            Divider()
            
            Button("聚焦第一个面板") {
                appState.paneManager.focusPane(index: 0)
            }
            .keyboardShortcut("1", modifiers: [.command])
            
            Button("聚焦第二个面板") {
                appState.paneManager.focusPane(index: 1)
            }
            .keyboardShortcut("2", modifiers: [.command])
        }
    }
}

// MARK: - Notification Names (仅保留仍需通过通知传递的)

extension Notification.Name {
    static let runAllRules = Notification.Name("runAllRules")
}
