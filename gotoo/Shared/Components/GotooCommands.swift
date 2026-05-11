import SwiftUI

struct GotooAppKey: FocusedValueKey {
    typealias Value = AppState
}

extension FocusedValues {
    var appState: GotooAppKey.Value? {
        get { self[GotooAppKey.self] }
        set { self[GotooAppKey.self] = newValue }
    }
}

struct GotooCommands: Commands {
    @FocusedValue(\.appState) private var appState
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建文件夹") {
                let dir = appState?.paneManager.activePane.currentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
                let _ = try? FileEngine().createFolder(at: dir, name: "未命名文件夹")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        
        CommandMenu("面板") {
            Button("切换到下一个面板") {
                appState?.paneManager.nextPane()
            }
            .keyboardShortcut("u")
            
            Divider()
            
            Button("单栏布局") { appState?.paneManager.setLayout(.single) }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("双栏布局") { appState?.paneManager.setLayout(.dual) }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("三栏布局") { appState?.paneManager.setLayout(.triple) }
                .keyboardShortcut("3", modifiers: [.command, .shift])
        }
        
        CommandMenu("视图") {
            Button("切换侧边栏") {
                // NavigationSplitView handles this natively
            }
            .keyboardShortcut("s", modifiers: [.command])
        }
        
        CommandMenu("AI") {
            Button("打开 AI 面板") {
                appState?.showAIPanel.toggle()
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
