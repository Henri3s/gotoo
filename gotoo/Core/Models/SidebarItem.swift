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
    
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var fileExtension: String { url.pathExtension.lowercased() }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
