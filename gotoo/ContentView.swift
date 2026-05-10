import SwiftUI

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        } detail: {
            ZStack {
                BrowserView()
                
                // AI Panel overlay (右侧)
                if appState.showAIPanel {
                    HStack(spacing: 0) {
                        Spacer()
                        AIPanelView()
                            .frame(width: 350)
                            .background(.background)
                    }
                }
            }
        }
        .navigationTitle(appState.currentDirectory.lastPathComponent)
        .sheet(isPresented: Binding(
            get: { appState.showRulesPanel },
            set: { appState.showRulesPanel = $0 }
        )) {
            RulesView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }
}
