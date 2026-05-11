import SwiftUI

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var showSidebar = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 全局工具栏
            globalToolbar
            
            Divider()
            
            HStack(spacing: 0) {
                // 侧边栏
                if showSidebar {
                    sidebarContent
                    Divider()
                }
                
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
        }
        .navigationTitle("Gotoo")
        .focusedValue(\.appState, appState)
        .sheet(isPresented: Binding(get: { appState.showRulesPanel }, set: { appState.showRulesPanel = $0 })) {
            RulesView().frame(minWidth: 600, minHeight: 500)
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // 系统收藏
            List {
                Section("收藏夹") {
                    ForEach(FileEngine.favorites, id: \.0) { name, url in
                        Button {
                            appState.paneManager.activePane.navigateTo(url)
                        } label: {
                            Label(name, systemImage: SidebarItem.favorites(name, url).systemImage)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if !appState.customFavorites.isEmpty {
                    Section("自定义") {
                        ForEach(appState.customFavorites, id: \.0) { name, url in
                            Button {
                                appState.paneManager.activePane.navigateTo(url)
                            } label: {
                                Label(name, systemImage: "folder.fill").font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(width: 180)
            
            Divider()
            
            // 管理按钮
            HStack {
                Button { showSidebar = false } label: {
                    Image(systemName: "sidebar.left").font(.caption)
                }
                Spacer()
                Button {
                    // Show favorites manager
                } label: {
                    Image(systemName: "plus").font(.caption)
                }
            }
            .padding(6)
            .background(.bar)
        }
    }
    
    // MARK: - Global Toolbar
    
    private var globalToolbar: some View {
        HStack(spacing: 10) {
            // 侧边栏
            Button { showSidebar.toggle() } label: {
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
            
            Button { appState.showAIPanel.toggle() } label: {
                Image(systemName: "sparkles")
            }
            
            Button { appState.showRulesPanel.toggle() } label: {
                Image(systemName: "gearshape")
            }
            
            Button {
                let _ = try? FileEngine().createFolder(at: appState.paneManager.activePane.currentDirectory, name: "未命名文件夹")
            } label: {
                Image(systemName: "folder.badge.plus")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
