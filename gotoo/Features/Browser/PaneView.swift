import SwiftUI
import UniformTypeIdentifiers

/// 单面板内容视图 — HIG 风格
struct PaneContentView: View {
    @Bindable var pane: PaneState
    let isActive: Bool
    let fileEngine = FileEngine()
    @State private var previewFile: FileItem?
    
    var body: some View {
        VStack(spacing: 0) {
            pathBar
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
    }
    
    // MARK: - Path Bar
    
    private var pathBar: some View {
        let comps = pane.currentDirectory.pathComponents
        return HStack(spacing: 4) {
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
                            pane.navigateTo(url)
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
            ForEach(pane.files) { file in
                FileRow(file: file)
                    .tag(file.url)
                    .contextMenu { contextMenu(for: file) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if pane.isLoading {
                ProgressView()
            } else if pane.files.isEmpty {
                ContentUnavailableView {
                    Label("空文件夹", systemImage: "folder")
                } description: {
                    Text("此文件夹没有可见内容")
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
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenu(for file: FileItem) -> some View {
        Button("打开") {
            if file.isDirectory { pane.navigateTo(file.url) }
            else { NSWorkspace.shared.open(file.url) }
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
    
    private func loadFiles() {
        pane.isLoading = true
        do { pane.files = try fileEngine.contents(of: pane.currentDirectory) }
        catch { pane.errorMessage = error.localizedDescription }
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
