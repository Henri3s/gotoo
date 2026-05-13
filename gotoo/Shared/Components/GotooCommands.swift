import SwiftUI
import AppKit

/// App 菜单命令
/// 注意: Commands 不是 View，不能使用 @Environment
/// 必须通过 AppState.shared 单例访问
struct GotooCommands: Commands {
    
    var body: some Commands {
        // 文件菜单
        CommandGroup(after: .newItem) {
            Button("新建文件夹") {
                let dir = AppState.shared.paneManager.activePane.currentDirectory
                let fm = FileManager.default
                var idx = 0
                var name = "未命名文件夹"
                while fm.fileExists(atPath: dir.appendingPathComponent(name).path) {
                    idx += 1
                    name = "未命名文件夹 \(idx)"
                }
                try? fm.createDirectory(at: dir.appendingPathComponent(name), withIntermediateDirectories: false)
                NotificationCenter.default.post(name: .refreshCurrentPane, object: nil)
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
                _ = AppState.shared.operationHistory.undo()
            }
            .keyboardShortcut("z", modifiers: [.command])
            
            Divider()
            
            Button("拷贝路径") {
                if let url = AppState.shared.paneManager.activePane.selectedFiles.first {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path, forType: .string)
                } else {
                    let dir = AppState.shared.paneManager.activePane.currentDirectory
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(dir.path, forType: .string)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        
        // 视图菜单
        CommandMenu("视图") {
            Picker("面板布局", selection: Binding(
                get: { AppState.shared.paneManager.layout },
                set: { AppState.shared.paneManager.setLayout($0) }
            )) {
                Text("单栏").tag(PaneLayout.single)
                Text("双栏").tag(PaneLayout.dual)
                Text("三栏").tag(PaneLayout.triple)
            }
            
            Divider()
            
            Button("切换 AI 面板") {
                AppState.shared.showAIPanel.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            
            Button("刷新") {
                NotificationCenter.default.post(name: .refreshCurrentPane, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])
            
            Divider()
            
            Button("切换到下一面板") {
                AppState.shared.paneManager.nextPane()
            }
            .keyboardShortcut("\\", modifiers: [.command])
        }
        
        // 工具菜单
        CommandMenu("工具") {
            Button("自动化规则...") {
                AppState.shared.showRulesPanel = true
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            
            Button("技能库...") {
                AppState.shared.showSkillPanel = true
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            
            Button("规则模板...") {
                AppState.shared.showTemplatePanel = true
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Divider()
            
            Button("文件夹配置...") {
                AppState.shared.showFolderConfigPanel = true
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Button("操作历史...") {
                AppState.shared.showHistoryPanel = true
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            
            Divider()
            
            Button("立即执行所有规则") {
                NotificationCenter.default.post(name: .runAllRules, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        
        // 跳转菜单
        CommandMenu("跳转") {
            Button("后退") {
                let parent = AppState.shared.paneManager.activePane.currentDirectory.deletingLastPathComponent()
                AppState.shared.paneManager.activePane.navigateTo(parent)
            }
            .keyboardShortcut("[", modifiers: [.command])
            
            Button("前进") {
                // TODO: 前进栈
            }
            .keyboardShortcut("]", modifiers: [.command])
            
            Divider()
            
            Button("聚焦第一个面板") {
                AppState.shared.paneManager.focusPane(index: 0)
            }
            .keyboardShortcut("1", modifiers: [.command])
            
            Button("聚焦第二个面板") {
                AppState.shared.paneManager.focusPane(index: 1)
            }
            .keyboardShortcut("2", modifiers: [.command])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let runAllRules = Notification.Name("runAllRules")
}
