import SwiftUI

struct GotooCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建文件夹") {
                // TODO: create folder
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        
        CommandMenu("文件操作") {
            Button("移到废纸篓") { }
                .keyboardShortcut(.delete, modifiers: .command)
            Button("在 Finder 中显示") { }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        
        CommandMenu("AI") {
            Button("打开 AI 面板") { }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}
