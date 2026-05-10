import SwiftUI

struct GotooCommands: Commands {
    @Environment(AppState.self) private var appState
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建文件夹") {
                let _ = try? FileEngine().createFolder(
                    at: appState.paneManager.activePane.currentDirectory,
                    name: "未命名文件夹"
                )
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Button("新建标签页") {
                appState.paneManager.activePane.addTab(directory: appState.paneManager.activePane.currentDirectory)
            }
            .keyboardShortcut("t")
            
            Button("关闭标签页") {
                appState.paneManager.activePane.closeTab(id: appState.paneManager.activePane.activeTabId)
            }
            .keyboardShortcut("w")
        }
        
        CommandMenu("面板") {
            Button("切换到下一个面板") {
                appState.paneManager.nextPane()
            }
            .keyboardShortcut("u")
            
            Divider()
            
            Button("单栏布局") { appState.paneManager.setLayout(.single) }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("双栏布局") { appState.paneManager.setLayout(.dual) }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("三栏布局") { appState.paneManager.setLayout(.triple) }
                .keyboardShortcut("3", modifiers: [.command, .shift])
        }
        
        CommandMenu("视图") {
            Button("切换侧边栏") { }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("切换预览面板") { }
                .keyboardShortcut("p", modifiers: [.command, .shift])
        }
        
        CommandMenu("AI") {
            Button("打开 AI 面板") {
                appState.showAIPanel.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }
        
        CommandMenu("文件操作") {
            Button("拷贝路径") { }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("在终端中打开") { }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button("移到废纸篓") { }
                .keyboardShortcut(.delete, modifiers: .command)
            Button("在 Finder 中显示") { }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
