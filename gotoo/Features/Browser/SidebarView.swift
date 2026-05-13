import SwiftUI

/// 原生 Sidebar — 使用 List + Section，HIG 标准 sidebar 样式
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showFavoritesManager = false
    
    private let defaultFavorites: [(name: String, url: URL)] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("主目录", home),
            ("桌面", home.appendingPathComponent("Desktop")),
            ("文稿", home.appendingPathComponent("Documents")),
            ("下载", home.appendingPathComponent("Downloads")),
            ("图片", home.appendingPathComponent("Pictures")),
            ("音乐", home.appendingPathComponent("Music")),
            ("影片", home.appendingPathComponent("Movies")),
        ]
    }()
    
    var body: some View {
        List {
            Section("收藏夹") {
                ForEach(defaultFavorites, id: \.name) { item in
                    Button {
                        appState.paneManager.activePane.navigateTo(item.url)
                    } label: {
                        Label(item.name, systemImage: iconForFavorite(item.name))
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
                        .contextMenu {
                            Button("移除", role: .destructive) {
                                appState.customFavorites.removeAll { $0.name == item.name }
                            }
                        }
                    }
                }
            }
            
            Section("工具") {
                Button {
                    appState.showRulesPanel = true
                } label: {
                    Label("自动化规则", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                
                Button {
                    appState.showSkillPanel = true
                } label: {
                    Label("技能库", systemImage: "star")
                }
                .buttonStyle(.plain)
                
                Button {
                    appState.showTemplatePanel = true
                } label: {
                    Label("规则模板", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.plain)
                
                Divider()
                
                Button {
                    showFavoritesManager = true
                } label: {
                    Label("管理收藏夹", systemImage: "star.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showFavoritesManager) {
            FavoritesManagerView()
                .environment(appState)
                .frame(width: 450, height: 400)
        }
    }
    
    private func iconForFavorite(_ name: String) -> String {
        switch name {
        case "主目录": return "house"
        case "桌面": return "menubar.dock.rectangle"
        case "文稿": return "doc"
        case "下载": return "arrow.down.circle"
        case "图片": return "photo"
        case "音乐": return "music.note"
        case "影片": return "film"
        default: return "folder"
        }
    }
}
