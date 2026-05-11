import SwiftUI

/// 主窗口 — 使用 NavigationSplitView 提供原生 sidebar + detail 布局
struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar
            SidebarView()
        } detail: {
            // MARK: - Detail (多面板)
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .focusedValue(\.appState, appState)
        .sheet(isPresented: Binding(
            get: { appState.showRulesPanel },
            set: { appState.showRulesPanel = $0 }
        )) {
            RulesView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        let paneCount = appState.paneManager.layout.count
        let activeIdx = appState.paneManager.activePaneIndex
        
        // 用 HSplitView 实现原生分割面板
        HSplitView {
            ForEach(0..<paneCount, id: \.self) { index in
                let pane = appState.paneManager.panes[index]
                PaneContentView(pane: pane, isActive: index == activeIdx)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        appState.paneManager.focusPane(index: index)
                    }
            }
        }
        .toolbar {
            // 左侧：导航
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    let parent = appState.paneManager.activePane.currentDirectory.deletingLastPathComponent()
                    appState.paneManager.activePane.navigateTo(parent)
                } label: {
                    Label("后退", systemImage: "chevron.backward")
                }
                .help("后退")
                
                Button {
                    loadActivePane()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("刷新")
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // 布局切换
                Picker("布局", selection: Binding(
                    get: { appState.paneManager.layout },
                    set: { appState.paneManager.setLayout($0) }
                )) {
                    ForEach(PaneLayout.allCases) { layout in
                        Image(systemName: layout == .single ? "rectangle" : layout == .dual ? "rectangle.split.1x2" : "rectangle.split.1x3")
                            .tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                
                Divider()
                
                Button {
                    let _ = try? FileEngine().createFolder(
                        at: appState.paneManager.activePane.currentDirectory,
                        name: "未命名文件夹"
                    )
                    loadActivePane()
                } label: {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }
                .help("新建文件夹")
                
                Button {
                    appState.showRulesPanel.toggle()
                } label: {
                    Label("自动化规则", systemImage: "gearshape")
                }
                .help("自动化规则")
                
                Button {
                    appState.showAIPanel.toggle()
                } label: {
                    Label("AI 助手", systemImage: "sparkles")
                }
                .help("AI 助手")
            }
        }
    }
    
    private func loadActivePane() {
        let pane = appState.paneManager.activePane
        let engine = FileEngine()
        do {
            pane.files = try engine.contents(of: pane.currentDirectory)
        } catch {
            pane.errorMessage = error.localizedDescription
        }
    }
}
