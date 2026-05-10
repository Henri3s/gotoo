import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        List(selection: Binding(
            get: { appState.selectedSidebarItem },
            set: { newItem in
                appState.selectedSidebarItem = newItem
                if let url = newItem?.url {
                    appState.navigateTo(url)
                }
            }
        )) {
            Section("收藏夹") {
                ForEach(FileEngine.favorites, id: \.0) { name, url in
                    let item = SidebarItem.favorites(name, url)
                    Label(name, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Gotoo")
    }
}
