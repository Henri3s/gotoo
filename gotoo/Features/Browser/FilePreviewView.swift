import SwiftUI

/// Quick Look 风格的文件预览面板
struct FilePreviewView: View {
    let file: FileItem
    @State private var quickLookURL: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // 文件信息头
            HStack {
                Image(nsImage: file.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }
            .padding(8)
            .background(.bar)
            
            Divider()
            
            // 预览区域
            previewContent
            
            Divider()
            
            // 文件详情
            fileDetails
        }
        .frame(maxHeight: 250)
        .background(.background)
    }
    
    @ViewBuilder
    private var previewContent: some View {
        let ext = file.fileExtension
        
        if file.isDirectory {
            VStack {
                Image(systemName: "folder")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("文件夹")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"].contains(ext) {
            AsyncImageView(url: file.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if ["txt", "md", "json", "xml", "yaml", "yml", "csv", "log", "swift", "py", "js", "html", "css", "sh"].contains(ext) {
            TextFilePreview(url: file.url)
        } else if ["pdf"].contains(ext) {
            VStack {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Button("用 Quick Look 查看") { quickLookURL = file.url }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack {
                Image(nsImage: file.icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                Text(ext.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var fileDetails: some View {
        HStack(spacing: 16) {
            if !file.isDirectory {
                Label(file.formattedSize, systemImage: "arrow.up.arrow.down")
            }
            if let date = file.modificationDate {
                Label(date.formatted(.dateTime.year().month().day().hour().minute()), systemImage: "clock")
            }
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(6)
        .background(.bar)
    }
}

// MARK: - Async Image

struct AsyncImageView: View {
    let url: URL
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .task { image = NSImage(contentsOf: url) }
            }
        }
    }
}

// MARK: - Text File Preview

struct TextFilePreview: View {
    let url: URL
    @State private var text: String = ""
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .task {
            text = (try? String(contentsOf: url, encoding: .utf8).prefix(2000).description) ?? "无法预览"
        }
    }
}
