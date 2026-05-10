import SwiftUI

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // 全局工具栏
            globalToolbar
            
            Divider()
            
            // 面板区域
            HStack(spacing: 1) {
                ForEach(Array(appState.paneManager.panes.prefix(appState.paneManager.layout.count).enumerated()), id: \.offset) { index, pane in
                    PaneView(pane: pane, isActive: index == appState.paneManager.activePaneIndex)
                        .onTapGesture {
                            appState.paneManager.focusPane(index: index)
                        }
                }
            }
        }
        .navigationTitle("Gotoo")
        .sheet(isPresented: Binding(get: { appState.showRulesPanel }, set: { appState.showRulesPanel = $0 })) {
            RulesView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }
    
    // MARK: - Global Toolbar
    
    private var globalToolbar: some View {
        HStack(spacing: 10) {
            // 侧边栏按钮
            Menu {
                ForEach(FileEngine.favorites, id: \.0) { name, url in
                    Button(name) {
                        appState.paneManager.activePane.navigateTo(url)
                    }
                }
            } label: {
                Image(systemName: "sidebar.left")
            }
            
            // 面板布局
            Picker("布局", selection: Binding(
                get: { appState.paneManager.layout },
                set: { appState.paneManager.setLayout($0) }
            )) {
                ForEach(PaneLayout.allCases) { layout in
                    Image(systemName: layout.systemImage).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            
            Divider().frame(height: 16)
            
            // 搜索
            TextField("搜索", text: Binding(
                get: { appState.paneManager.activePane.searchQuery },
                set: { appState.paneManager.activePane.searchQuery = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 180)
            
            Spacer()
            
            // AI 按钮
            Button { appState.showAIPanel.toggle() } label: {
                Image(systemName: "sparkles")
            }
            
            // 规则按钮
            Button { appState.showRulesPanel.toggle() } label: {
                Image(systemName: "gearshape")
            }
            
            // 新建文件夹
            Button {
                if let url = try? FileEngine().createFolder(at: appState.paneManager.activePane.currentDirectory, name: "未命名文件夹") {
                    // 刷新
                }
            } label: {
                Image(systemName: "folder.badge.plus")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
