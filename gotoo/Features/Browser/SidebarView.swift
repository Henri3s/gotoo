import SwiftUI

/// 原生 Sidebar — 使用 List + Section，HIG 标准 sidebar 样式
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        List {
            Section("收藏夹") {
                ForEach(FileEngine.favorites, id: \.0) { name, url in
                    Button {
                        appState.paneManager.activePane.navigateTo(url)
                    } label: {
                        Label(name, systemImage: iconForFavorite(name))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !appState.customFavorites.isEmpty {
                Section("自定义") {
                    ForEach(appState.customFavorites, id: \.name) { item in
                        Button {
                            appState.paneManager.activePane.navigateTo(item.url)
                        } label: {
                            Label(item.name, systemImage: "folder.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Gotoo")
    }
    
    private func iconForFavorite(_ name: String) -> String {
        switch name {
        case "主目录": return "house.fill"
        case "桌面": return "menubar.dock.rectangle"
        case "文稿": return "doc.fill"
        case "下载": return "arrow.down.circle.fill"
        case "图片": return "photo.fill"
        case "音乐": return "music.note"
        case "影片": return "film.fill"
        default: return "folder.fill"
        }
    }
}
