import SwiftUI
import UniformTypeIdentifiers

/// 单面板内容视图 — HIG 风格，支持双击导航、键盘操作
struct PaneContentView: View {
    @Bindable var pane: PaneState
    let isActive: Bool
    let fileEngine = FileEngine()
    @State private var previewFile: FileItem?
    @State private var searchQuery = ""
    @State private var sortField: SortField = .name
    @State private var sortAscending = true
    
    // 导航历史栈
    @State private var backStack: [URL] = []
    @State private var forwardStack: [URL] = []
    
    enum SortField: String, CaseIterable {
        case name = "名称"
        case size = "大小"
        case date = "修改日期"
        case kind = "类型"
    }
    
    var filteredFiles: [FileItem] {
        var result = pane.files
        if !searchQuery.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
        // 排序：文件夹始终在前
        result.sort { (a: FileItem, b: FileItem) -> Bool in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            let asc = sortAscending
            switch sortField {
            case .name: return asc ? a.name.localizedStandardCompare(b.name) == .orderedAscending : a.name.localizedStandardCompare(b.name) == .orderedDescending
            case .size: return asc ? a.size < b.size : a.size > b.size
            case .date:
                let ad = a.modificationDate ?? .distantPast
                let bd = b.modificationDate ?? .distantPast
                return asc ? ad < bd : ad > bd
            case .kind: return asc ? a.fileExtension < b.fileExtension : a.fileExtension > b.fileExtension
            }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            pathBar
            Divider()
            
            // 搜索栏
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索文件...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                sortMenu
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.bar)
            
            Divider()
            
            HStack(spacing: 0) {
                fileListBody
                if let file = previewFile {
                    Divider()
                    FilePreviewView(file: file).frame(width: 240)
                }
            }
            
            Divider()
            statusBar
        }
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                .padding(1)
        )
        .onAppear { loadFiles() }
        .onChange(of: pane.currentDirectory) { _, _ in loadFiles() }
        // 文件系统变化时自动刷新
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemChanged)) { notification in
            if let changedURL = notification.object as? URL,
               changedURL.path.hasPrefix(pane.currentDirectory.path) {
                loadFiles()
            }
        }
        // 手动刷新
        .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPane)) { _ in
            loadFiles()
        }
    }
    
    // MARK: - Sort Menu
    
    private var sortMenu: some View {
        Menu {
            ForEach(SortField.allCases, id: \.self) { field in
                Button {
                    if sortField == field { sortAscending.toggle() }
                    else { sortField = field; sortAscending = true }
                } label: {
                    if sortField == field {
                        Label(field.rawValue, systemImage: sortAscending ? "chevron.up" : "chevron.down")
                    } else {
                        Text(field.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 20)
    }
    
    // MARK: - Path Bar
    
    private var pathBar: some View {
        let comps = pane.currentDirectory.pathComponents
        return HStack(spacing: 4) {
            // 后退按钮
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(backStack.isEmpty ? .tertiary : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(backStack.isEmpty)
            
            // 前进按钮
            Button {
                goForward()
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(forwardStack.isEmpty ? .tertiary : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(forwardStack.isEmpty)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(0..<comps.count, id: \.self) { i in
                        if i > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        let partial = "/" + comps[0...i].joined(separator: "/")
                        let url = URL(fileURLWithPath: partial)
                        Button {
                            navigateTo(url, recordHistory: true)
                        } label: {
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(i == comps.count - 1 ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }
    
    // MARK: - File List
    
    private var fileListBody: some View {
        List(selection: $pane.selectedFiles) {
            ForEach(filteredFiles) { file in
                FileRow(file: file)
                    .tag(file.url)
                    .contextMenu { contextMenu(for: file) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if pane.isLoading {
                ProgressView()
            } else if let error = pane.errorMessage {
                ContentUnavailableView {
                    Label("无法读取", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("重试") { loadFiles() }
                }
            } else if pane.files.isEmpty {
                ContentUnavailableView {
                    Label("空文件夹", systemImage: "folder")
                } description: {
                    Text("此文件夹没有可见内容")
                }
            } else if filteredFiles.isEmpty {
                ContentUnavailableView {
                    Label("无匹配结果", systemImage: "magnifyingglass")
                } description: {
                    Text("没有匹配 \"\(searchQuery)\" 的文件")
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
        .onChange(of: pane.selectedFiles) { _, sel in
            if let firstURL = sel.first,
               let f = pane.files.first(where: { $0.url == firstURL }) {
                previewFile = f
            } else {
                previewFile = nil
            }
        }
        .onKeyPress(.downArrow) { handleKeyDown(); return .handled }
        .onKeyPress(.upArrow) { handleKeyUp(); return .handled }
        .onKeyPress(.return) { handleKeyEnter(); return .handled }
        .onKeyPress(.delete) { handleKeyBackspace(); return .handled }
        .focusable()
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack(spacing: 8) {
            Text("\(pane.files.count) 个项目")
            if !pane.selectedFiles.isEmpty {
                Text("·")
                Text("已选 \(pane.selectedFiles.count) 个")
                    .foregroundStyle(Color.accentColor)
            }
            if !searchQuery.isEmpty {
                Text("·")
                Text("匹配 \(filteredFiles.count) 个")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let vol = freeSpace {
                Text("可用 \(ByteCountFormatter.string(fromByteCount: vol, countStyle: .file))")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }
    
    private var freeSpace: Int64? {
        (try? pane.currentDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))
            .flatMap { v in v.volumeAvailableCapacityForImportantUsage.map { Int64($0) } }
    }
    
    // MARK: - Navigation
    
    private func navigateTo(_ url: URL, recordHistory: Bool) {
        guard url != pane.currentDirectory else { return }
        if recordHistory {
            backStack.append(pane.currentDirectory)
            forwardStack.removeAll()
        }
        pane.navigateTo(url)
    }
    
    private func goBack() {
        guard let prev = backStack.popLast() else { return }
        forwardStack.append(pane.currentDirectory)
        pane.navigateTo(prev)
    }
    
    private func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(pane.currentDirectory)
        pane.navigateTo(next)
    }
    
    // MARK: - Keyboard
    
    private func handleKeyEnter() {
        guard let selectedURL = pane.selectedFiles.first,
              let file = pane.files.first(where: { $0.url == selectedURL }) else { return }
        if file.isDirectory {
            navigateTo(file.url, recordHistory: true)
        } else {
            NSWorkspace.shared.open(file.url)
        }
    }
    
    private func handleKeyBackspace() {
        let parent = pane.currentDirectory.deletingLastPathComponent()
        if parent != pane.currentDirectory {
            navigateTo(parent, recordHistory: true)
        }
    }
    
    private func handleKeyDown() {
        let files = filteredFiles
        guard !files.isEmpty else { return }
        if pane.selectedFiles.isEmpty {
            pane.selectedFiles = [files[0].url]
        } else if let currentURL = pane.selectedFiles.first,
                  let idx = files.firstIndex(where: { $0.url == currentURL }),
                  idx + 1 < files.count {
            pane.selectedFiles = [files[idx + 1].url]
        }
    }
    
    private func handleKeyUp() {
        let files = filteredFiles
        guard !files.isEmpty else { return }
        if pane.selectedFiles.isEmpty {
            pane.selectedFiles = [files[0].url]
        } else if let currentURL = pane.selectedFiles.first,
                  let idx = files.firstIndex(where: { $0.url == currentURL }),
                  idx > 0 {
            pane.selectedFiles = [files[idx - 1].url]
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenu(for file: FileItem) -> some View {
        Button("打开") {
            if file.isDirectory {
                navigateTo(file.url, recordHistory: true)
            } else {
                NSWorkspace.shared.open(file.url)
            }
        }
        Button("在 Finder 中显示") {
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
        }
        Divider()
        if file.isDirectory {
            Button("在终端中打开") {
                let t = Process()
                t.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                t.arguments = ["-a", "Terminal", file.url.path]
                try? t.run()
            }
        }
        Button("拷贝路径") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.url.path, forType: .string)
        }
        Divider()
        if pane.selectedFiles.count > 1 {
            Button("移到废纸篓 (\(pane.selectedFiles.count) 个)", role: .destructive) {
                for url in pane.selectedFiles { _ = try? fileEngine.trash(url) }
                pane.selectedFiles.removeAll()
                loadFiles()
            }
        }
        Button("移到废纸篓", role: .destructive) {
            _ = try? fileEngine.trash(file.url)
            loadFiles()
        }
    }
    
    // MARK: - Helpers
    
    func loadFiles() {
        pane.isLoading = true
        pane.errorMessage = nil
        do {
            pane.files = try fileEngine.contents(of: pane.currentDirectory)
        } catch {
            pane.errorMessage = error.localizedDescription
            pane.files = []
        }
        pane.isLoading = false
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for p in providers {
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let d = data as? Data, let url = URL(dataRepresentation: d, relativeTo: nil) else { return }
                Task { @MainActor in
                    try? self.fileEngine.move(from: url, to: self.pane.currentDirectory)
                    self.loadFiles()
                }
            }
        }
        return true
    }
}

// MARK: - Notification for file system changes

extension Notification.Name {
    static let fileSystemChanged = Notification.Name("fileSystemChanged")
    static let refreshCurrentPane = Notification.Name("refreshCurrentPane")
}

// MARK: - File Row

struct FileRow: View {
    let file: FileItem
    
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: file.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            Text(file.name).font(.body).lineLimit(1)
            Spacer()
            if !file.isDirectory {
                Text(file.formattedSize).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if let d = file.modificationDate {
                    Text(d, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 1)
    }
}
