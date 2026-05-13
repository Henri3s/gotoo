import Foundation
import AppKit

enum SidebarItem: Hashable, Identifiable {
    case favorites(String, URL)
    
    var id: String {
        switch self {
        case .favorites(let name, _): return "fav-\(name)"
        }
    }
    
    var displayName: String {
        switch self {
        case .favorites(let name, _): return name
        }
    }
    
    var url: URL? {
        switch self {
        case .favorites(_, let url): return url
        }
    }
    
    var systemImage: String {
        switch self {
        case .favorites(let name, _):
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
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let creationDate: Date?
    
    // MARK: - Cached Properties (computed once)
    
    /// 图标缓存 — 避免列表滚动时反复生成 NSImage
    private static var iconCache: [String: NSImage] = [:]
    
    var icon: NSImage {
        if let cached = Self.iconCache[url.path] { return cached }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        Self.iconCache[url.path] = img
        return img
    }
    
    /// ByteCountFormatter 缓存
    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    
    var formattedSize: String {
        Self.sizeFormatter.string(fromByteCount: size)
    }
    
    var fileExtension: String { url.pathExtension.lowercased() }
    
    /// macOS Finder 标签颜色
    var labelColor: FileLabelColor {
        // macOS Finder label 通过 extended attributes 实现
        // 简化实现：返回 .none（后续通过 com.apple.FinderInfo 实现）
        return .none
    }
    
    /// macOS Finder 标签
    var tags: [FileTag] {
        guard let tagNames = try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames else { return [] }
        return tagNames.map { FileTag(name: $0) }
    }
    
    /// 文件类型分类
    var category: FileCategory {
        if isDirectory { return .folder }
        if FileCategories.imageExtensions.contains(fileExtension) { return .image }
        if FileCategories.videoExtensions.contains(fileExtension) { return .video }
        if FileCategories.audioExtensions.contains(fileExtension) { return .audio }
        if FileCategories.documentExtensions.contains(fileExtension) { return .document }
        if FileCategories.archiveExtensions.contains(fileExtension) { return .archive }
        if FileCategories.codeExtensions.contains(fileExtension) { return .code }
        return .other
    }
    
    /// 分类图标
    var categoryIcon: String {
        category.systemImage
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

// MARK: - File Category

enum FileCategory: String, CaseIterable {
    case folder = "文件夹"
    case image = "图片"
    case video = "视频"
    case audio = "音频"
    case document = "文档"
    case archive = "压缩包"
    case code = "代码"
    case pdf = "PDF"
    case other = "其他"
    
    var systemImage: String {
        switch self {
        case .folder: return "folder"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .document: return "doc"
        case .archive: return "doc.zipper"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .pdf: return "doc.richtext"
        case .other: return "doc.questionmark"
        }
    }
    
    var color: String {
        switch self {
        case .folder: return "blue"
        case .image: return "green"
        case .video: return "purple"
        case .audio: return "pink"
        case .document: return "orange"
        case .archive: return "yellow"
        case .code: return "cyan"
        case .pdf: return "red"
        case .other: return "gray"
        }
    }
}

// MARK: - File Tag

struct FileTag: Hashable, Identifiable {
    let id = UUID()
    let name: String
    
    static let presets: [FileTag] = [
        FileTag(name: "重要"),
        FileTag(name: "工作"),
        FileTag(name: "个人"),
        FileTag(name: "待处理"),
        FileTag(name: "已完成"),
        FileTag(name: "参考"),
        FileTag(name: "临时"),
    ]
}
