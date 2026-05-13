import SwiftUI
import SwiftData

/// 主窗口 — 使用 NavigationSplitView 提供原生 sidebar + detail 布局
struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: Binding(
            get: { appState.showRulesPanel },
            set: { appState.showRulesPanel = $0 }
        )) {
            RulesView()
                .frame(minWidth: 700, minHeight: 550)
        }
        .sheet(isPresented: Binding(
            get: { appState.showSkillPanel },
            set: { appState.showSkillPanel = $0 }
        )) {
            SkillBrowserView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: Binding(
            get: { appState.showFolderConfigPanel },
            set: { appState.showFolderConfigPanel = $0 }
        )) {
            FolderConfigView()
                .frame(minWidth: 550, minHeight: 500)
        }
        .sheet(isPresented: Binding(
            get: { appState.showHistoryPanel },
            set: { appState.showHistoryPanel = $0 }
        )) {
            HistoryPanelView()
                .frame(minWidth: 600, minHeight: 450)
        }
        .sheet(isPresented: Binding(
            get: { appState.showTemplatePanel },
            set: { appState.showTemplatePanel = $0 }
        )) {
            TemplateBrowserView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        let paneCount = appState.paneManager.layout.count
        let activeIdx = appState.paneManager.activePaneIndex
        
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
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    let parent = appState.paneManager.activePane.currentDirectory.deletingLastPathComponent()
                    appState.paneManager.activePane.navigateTo(parent)
                } label: {
                    Label("后退", systemImage: "chevron.backward")
                }
                .help("后退")
                
                Button {
                    // 刷新由 PaneContentView 内部处理
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
                        Label(layout.rawValue, systemImage: layout.icon).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                
                Divider()
                
                // AI 面板
                Button {
                    appState.showAIPanel.toggle()
                } label: {
                    Label("AI 助手", systemImage: "sparkles")
                }
                .tint(appState.showAIPanel ? .accentColor : nil)
                
                // 技能
                Button {
                    appState.showSkillPanel = true
                } label: {
                    Label("技能", systemImage: "star")
                }
                
                // 规则
                Button {
                    appState.showRulesPanel = true
                } label: {
                    Label("规则", systemImage: "gearshape")
                }
                
                Divider()
                
                // 文件夹配置
                Button {
                    appState.showFolderConfigPanel = true
                } label: {
                    Label("文件夹配置", systemImage: "folder.badge.gearshape")
                }
                
                // 历史记录
                Button {
                    appState.showHistoryPanel = true
                } label: {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
                
                // 撤销
                Button {
                    _ = appState.operationHistory.undo()
                } label: {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                }
                .disabled(!appState.operationHistory.canUndo)
            }
        }
        
        // AI 面板 (右侧抽屉)
        .overlay(alignment: .trailing) {
            if appState.showAIPanel {
                AIPanelView()
                    .frame(width: 360)
                    .background(.regularMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: -2, y: 0)
                    .transition(.move(edge: .trailing))
            }
        }
    }
}

// MARK: - Pane Layout Icon

extension PaneLayout {
    var icon: String {
        switch self {
        case .single: return "rectangle"
        case .dual: return "rectangle.split.1x2"
        case .triple: return "rectangle.split.1x3"
        }
    }
}
