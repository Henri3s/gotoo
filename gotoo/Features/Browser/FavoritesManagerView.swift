import SwiftUI
import SwiftData

/// 自定义收藏夹管理视图
struct FavoritesManagerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var newFavoritePath = ""
    @State private var newFavoriteName = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("管理收藏夹").font(.headline)
            
            List {
                ForEach(appState.customFavorites, id: \.0) { name, url in
                    HStack {
                        Image(systemName: "folder")
                        Text(name).font(.body)
                        Text(url.path).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            appState.customFavorites.removeAll(where: { $0.0 == name })
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                    }
                }
            }
            .frame(minHeight: 200)
            
            HStack {
                TextField("名称", text: $newFavoriteName)
                    .frame(width: 100)
                TextField("路径", text: $newFavoritePath)
                Button("选择") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = true
                    if panel.runModal() == .OK, let url = panel.url {
                        newFavoritePath = url.path
                        if newFavoriteName.isEmpty { newFavoriteName = url.lastPathComponent }
                    }
                }
                Button("添加") {
                    guard !newFavoriteName.isEmpty, !newFavoritePath.isEmpty else { return }
                    appState.customFavorites.append((newFavoriteName, URL(fileURLWithPath: newFavoritePath)))
                    newFavoriteName = ""
                    newFavoritePath = ""
                }
                .disabled(newFavoriteName.isEmpty || newFavoritePath.isEmpty)
            }
            
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 450, height: 350)
    }
}
