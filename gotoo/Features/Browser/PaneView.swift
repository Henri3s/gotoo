import SwiftUI
import UniformTypeIdentifiers

/// 单个面板视图（含标签页、文件列表、拖放、预览）
struct PaneView: View {
    @Bindable var pane: PaneState
    let isActive: Bool
    let onDropToPane: ((FileItem, PaneState) -> Void)?
    let fileEngine = FileEngine()
    @State private var previewFile: FileItem?
    @State private var renameTarget: FileItem?
    @State private var newName = ""
    
    init(pane: PaneState, isActive: Bool, onDropToPane: ((FileItem, PaneState) -> Void)? = nil) {
        self._pane = .init(wrappedValue: pane)
        self.isActive = isActive
        self.onDropToPane = onDropToPane
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            addressBar
            Divider()
            
            HStack(spacing: 0) {
                // 文件列表
                fileListBody
                
                // 预览面板
                if let file = previewFile {
                    Divider()
                    FilePreviewView(file: file)
                        .frame(width: 250)
                }
            }
            
            Divider()
            statusBar
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onAppear { loadFiles() }
        .onChange(of: pane.currentDirectory) { _, _ in loadFiles() }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(pane.tabs) { tab in
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(tab.title)
                            .font(.caption)
                            .lineLimit(1)
                        
                        if pane.tabs.count > 1 {
                            Button { pane.closeTab(id: tab.id); loadFiles() } label: {
                                Image(systemName: "xmark").font(.system(size: 7)).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tab.id == pane.activeTabId ? Color.accentColor.opacity(0.15) : Color.clear)
                    .onTapGesture { pane.switchTab(id: tab.id); loadFiles() }
                }
                
                Button { pane.addTab(directory: pane.currentDirectory); loadFiles() } label: {
                    Image(systemName: "plus").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 26)
        .background(.bar)
    }
    
    // MARK: - Address Bar
    
    private var addressBar: some View {
        HStack(spacing: 6) {
            Button {
                let parent = pane.currentDirectory.deletingLastPathComponent()
                pane.navigateTo(parent)
            } label: {
                Image(systemName: "chevron.left").font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(pane.currentDirectory.pathComponents.count <= 1)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    let comps = pane.currentDirectory.pathComponents
                    ForEach(Array(comps.indices), id: \.self) { i in
                        if i > 0 { Text("/").font(.caption2).foregroundStyle(.tertiary) }
                        let partial = "/" + comps[0...i].joined(separator: "/")
                        let url = URL(fileURLWithPath: partial)
                        Button(url.lastPathComponent) { pane.navigateTo(url) }
                            .buttonStyle(.plain).font(.caption)
                            .foregroundStyle(i == comps.count - 1 ? .primary : .secondary)
                    }
                }
            }
            
            Spacer()
            
            Button { previewFile = nil } label: {
                Image(systemName: "eye").font(.caption)
            }
            .buttonStyle(.plain)
            .opacity(previewFile != nil ? 1 : 0.4)
            
            Button { loadFiles() } label: {
                Image(systemName: "arrow.clockwise").font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }
    
    // MARK: - File List
    
    private var filteredFiles: [FileItem] {
        if pane.searchQuery.isEmpty { return pane.files }
        return pane.files.filter { $0.name.localizedCaseInsensitiveContains(pane.searchQuery) }
    }
    
    private var fileListBody: some View {
        let files = filteredFiles
        
        return List(selection: $pane.selectedFiles) {
            ForEach(files) { file in
                FileRow(file: file)
                    .tag(file.url)
                    .onTapGesture(count: 2) {
                        if file.isDirectory { pane.navigateTo(file.url) }
                        else { NSWorkspace.shared.open(file.url) }
                    }
                    .contextMenu { fileContextMenu(for: file) }
            }
        }
        .listStyle(.inset)
        .overlay {
            if pane.isLoading {
                ProgressView("加载中...")
            } else if files.isEmpty {
                ContentUnavailableView("空文件夹", systemImage: "folder")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .onChange(of: pane.selectedFiles) { _, newSelection in
            if let firstURL = newSelection.first,
               let firstFile = files.first(where: { $0.url == firstURL }) {
                previewFile = firstFile
            } else {
                previewFile = nil
            }
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack {
            Text("\(filteredFiles.count) 个项目")
                .font(.caption2).foregroundStyle(.secondary)
            if !pane.selectedFiles.isEmpty {
                Text("· 已选 \(pane.selectedFiles.count) 个")
                    .font(.caption2).foregroundStyle(Color.accentColor)
            }
            Spacer()
            if let vol = volumeFreeSpace(for: pane.currentDirectory) {
                Text("可用 \(ByteCountFormatter.string(fromByteCount: vol, countStyle: .file))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(.bar)
    }
    
    // MARK: - Enhanced Context Menu
    
    @ViewBuilder
    private func fileContextMenu(for file: FileItem) -> some View {
        Button("打开") {
            if file.isDirectory { pane.navigateTo(file.url) }
            else { NSWorkspace.shared.open(file.url) }
        }
        Button("在 Finder 中显示") {
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
        }
        Button(file.isDirectory ? "在终端中打开" : "用...打开") {
            if file.isDirectory {
                // Open Terminal at this directory
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                task.arguments = ["-a", "Terminal", file.url.path]
                try? task.run()
            } else {
                NSWorkspace.shared.open(file.url)
            }
        }
        
        Divider()
        
        Button("预览") { previewFile = file }
        
        Button("拷贝路径") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.url.path, forType: .string)
        }
        
        Divider()
        
        Button("新建文件夹") {
            if let url = try? fileEngine.createFolder(at: pane.currentDirectory, name: "未命名文件夹") {
                loadFiles()
            }
        }
        
        Button("重命名") {
            renameTarget = file
            newName = file.name
        }
        
        Divider()
        
        if !pane.selectedFiles.isEmpty && pane.selectedFiles.count > 1 {
            Button("批量删除 (\(pane.selectedFiles.count) 个文件)", role: .destructive) {
                for url in pane.selectedFiles {
                    try? fileEngine.trash(url)
                }
                pane.selectedFiles.removeAll()
                loadFiles()
            }
        }
        
        Button("移到废纸篓", role: .destructive) {
            try? fileEngine.trash(file.url)
            loadFiles()
        }
    }
    
    // MARK: - Actions
    
    private func loadFiles() {
        pane.isLoading = true
        pane.errorMessage = nil
        do {
            pane.files = try fileEngine.contents(of: pane.currentDirectory)
        } catch {
            pane.errorMessage = error.localizedDescription
        }
        pane.isLoading = false
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    try? self.fileEngine.move(from: url, to: self.pane.currentDirectory)
                    self.loadFiles()
                }
                handled = true
            }
        }
        return handled
    }
    
    private func volumeFreeSpace(for url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage.map { Int64($0) }
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: FileItem
    
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name).font(.body).lineLimit(1)
                if !file.isDirectory {
                    HStack(spacing: 6) {
                        Text(file.formattedSize).font(.caption2).foregroundStyle(.secondary)
                        if let d = file.modificationDate {
                            Text(d.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            if file.isDirectory {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
