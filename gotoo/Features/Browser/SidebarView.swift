import SwiftUI

/// 侧边栏弹出菜单（从全局工具栏触发）
struct SidebarPopup: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Section("收藏夹") {
                ForEach(FileEngine.favorites, id: \.0) { name, url in
                    Button {
                        appState.paneManager.activePane.navigateTo(url)
                    } label: {
                        Label(name, systemImage: SidebarItem.favorites(name, url).systemImage)
                    }
                }
            }
            
            if !appState.customFavorites.isEmpty {
                Divider()
                Section("自定义") {
                    ForEach(appState.customFavorites, id: \.0) { name, url in
                        Button {
                            appState.paneManager.activePane.navigateTo(url)
                        } label: {
                            Label(name, systemImage: "folder")
                        }
                    }
                }
            }
        }
    }
}
