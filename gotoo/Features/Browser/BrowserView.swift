import SwiftUI

struct BrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var files: [FileItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let fileEngine = FileEngine()
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 8) {
                Button {
                    let parent = appState.currentDirectory.deletingLastPathComponent()
                    appState.navigateTo(parent)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(appState.currentDirectory.pathComponents.count <= 1)
                
                Button { loadFiles() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                
                Spacer()
                
                TextField("搜索", text: $state.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Button { appState.showAIPanel.toggle() } label: {
                    Image(systemName: "sparkles")
                }
                
                Button { appState.showRulesPanel.toggle() } label: {
                    Image(systemName: "gearshape")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
            
            Divider()
            
            // 路径栏
            pathBar
            
            Divider()
            
            // 文件列表
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView("无法读取", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                fileList(filtered: filteredFiles)
            }
        }
        .navigationTitle(appState.currentDirectory.lastPathComponent)
        .onAppear { loadFiles() }
        .onChange(of: appState.currentDirectory) { _, _ in loadFiles() }
    }
    
    // MARK: - Path Bar
    
    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                let comps = appState.currentDirectory.pathComponents
                ForEach(Array(comps.indices), id: \.self) { i in
                    if i > 0 { Text("/").foregroundStyle(.secondary).font(.caption) }
                    let partial = "/" + comps[0...i].joined(separator: "/")
                    let url = URL(fileURLWithPath: partial)
                    Button(url.lastPathComponent) {
                        appState.navigateTo(url)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(i == comps.count - 1 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
    
    private var filteredFiles: [FileItem] {
        if appState.searchQuery.isEmpty { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(appState.searchQuery) }
    }
    
    private func fileList(filtered: [FileItem]) -> some View {
        @Bindable var state = appState
        return List(selection: $state.selectedFiles) {
            ForEach(filtered) { file in
                FileRow(file: file)
                    .tag(file.url)
                    .contextMenu {
                        Button("打开") { NSWorkspace.shared.open(file.url) }
                        Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                        Divider()
                        Button("移到废纸篓") {
                            try? fileEngine.trash(file.url)
                            loadFiles()
                        }
                    }
            }
        }
        .listStyle(.inset)
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView("空文件夹", systemImage: "folder")
            }
        }
    }
    
    private func loadFiles() {
        isLoading = true
        errorMessage = nil
        do {
            files = try fileEngine.contents(of: appState.currentDirectory)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct FileRow: View {
    let file: FileItem
    
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.body)
                if !file.isDirectory {
                    Text("\(file.formattedSize)  \(file.modificationDate?.formatted(.dateTime.year().month().day()) ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
