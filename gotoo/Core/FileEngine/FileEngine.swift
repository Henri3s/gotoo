import Foundation
import Observation

// MARK: - File Categories

enum FileCategories {
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif",
        "svg", "ico", "raw", "cr2", "nef", "orf", "sr2", "psd", "ai"
    ]
    static let videoExtensions: Set<String> = [
        "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg",
        "3gp", "ts", "vob"
    ]
    static let audioExtensions: Set<String> = [
        "mp3", "wav", "aac", "flac", "ogg", "wma", "m4a", "aiff", "alac",
        "opus", "mid", "midi"
    ]
    static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf",
        "odt", "ods", "odp", "pages", "numbers", "keynote", "md", "csv", "tsv"
    ]
    static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg"
    ]
    static let codeExtensions: Set<String> = [
        "swift", "py", "js", "ts", "java", "c", "cpp", "h", "hpp", "cs", "go",
        "rs", "rb", "php", "html", "css", "scss", "json", "xml", "yaml", "yml",
        "sh", "bash", "sql", "r", "kt", "scala", "lua", "vim", "el"
    ]
}

// MARK: - File Label Color

enum FileLabelColor: String, Codable, CaseIterable {
    case none = "无"
    case red = "红色"
    case orange = "橙色"
    case yellow = "黄色"
    case green = "绿色"
    case blue = "蓝色"
    case purple = "紫色"
    case gray = "灰色"
    
    var nsColor: NSColor? {
        switch self {
        case .none: return nil
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .gray: return .systemGray
        }
    }
}

import AppKit

// MARK: - FileEngine

@Observable
@MainActor
final class FileEngine {
    private let fm = FileManager.default
    
    // MARK: - Directory Listing
    
    func contents(of directory: URL) throws -> [FileItem] {
        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls.compactMap { url -> FileItem? in
            let vals = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey])
            return FileItem(
                url: url,
                name: url.lastPathComponent,
                isDirectory: vals?.isDirectory ?? false,
                size: Int64(vals?.fileSize ?? 0),
                modificationDate: vals?.contentModificationDate,
                creationDate: vals?.creationDate
            )
        }.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    /// 递归获取所有文件（异步，不阻塞主线程）
    func contentsRecursive(of directory: URL, maxDepth: Int = 10) async throws -> [FileItem] {
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            var result: [FileItem] = []
            self.enumerateRecursive(directory: directory, fm: fm, depth: 0, maxDepth: maxDepth, into: &result)
            return result
        }.value
    }
    
    /// 递归获取所有文件（同步版本，用于规则引擎）
    func contentsRecursiveSync(of directory: URL, maxDepth: Int = 10) throws -> [FileItem] {
        var result: [FileItem] = []
        enumerateRecursive(directory: directory, fm: fm, depth: 0, maxDepth: maxDepth, into: &result)
        return result
    }
    
    private nonisolated func enumerateRecursive(
        directory: URL,
        fm: FileManager,
        depth: Int,
        maxDepth: Int,
        into result: inout [FileItem]
    ) {
        guard depth < maxDepth else { return }
        
        guard let urls = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for url in urls {
            let vals = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey])
            let isDir = vals?.isDirectory ?? false
            
            let item = FileItem(
                url: url,
                name: url.lastPathComponent,
                isDirectory: isDir,
                size: Int64(vals?.fileSize ?? 0),
                modificationDate: vals?.contentModificationDate,
                creationDate: vals?.creationDate
            )
            
            result.append(item)
            
            if isDir {
                enumerateRecursive(directory: url, fm: fm, depth: depth + 1, maxDepth: maxDepth, into: &result)
            }
        }
    }
    
    /// 获取目录统计信息
    func statistics(of directory: URL) throws -> DirectoryStatistics {
        let items = try contents(of: directory)
        var stats = DirectoryStatistics()
        
        for item in items {
            if item.isDirectory {
                stats.folderCount += 1
            } else {
                stats.fileCount += 1
                stats.totalSize += item.size
                stats.categoryCounts[item.category, default: 0] += 1
            }
        }
        
        return stats
    }
    
    // MARK: - File Operations
    
    func move(from source: URL, to directory: URL) throws {
        let dest = directory.appendingPathComponent(source.lastPathComponent)
        var finalDest = dest
        var counter = 1
        while fm.fileExists(atPath: finalDest.path) {
            let name = dest.deletingPathExtension().lastPathComponent
            let ext = dest.pathExtension
            let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
            finalDest = directory.appendingPathComponent(newName)
            counter += 1
        }
        try fm.moveItem(at: source, to: finalDest)
    }
    
    func copy(from source: URL, to directory: URL) throws {
        let dest = directory.appendingPathComponent(source.lastPathComponent)
        var finalDest = dest
        var counter = 1
        while fm.fileExists(atPath: finalDest.path) {
            let name = dest.deletingPathExtension().lastPathComponent
            let ext = dest.pathExtension
            let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
            finalDest = directory.appendingPathComponent(newName)
            counter += 1
        }
        try fm.copyItem(at: source, to: finalDest)
    }
    
    @discardableResult
    func trash(_ url: URL) throws -> URL? {
        var result: NSURL?
        try fm.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }
    
    func rename(_ url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fm.moveItem(at: url, to: newURL)
        return newURL
    }
    
    func createFolder(at parent: URL, name: String) throws -> URL {
        let folder = parent.appendingPathComponent(name)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }
    
    /// 批量移动文件
    func batchMove(files: [URL], to directory: URL) -> [BatchResult] {
        var results: [BatchResult] = []
        for file in files {
            do {
                try move(from: file, to: directory)
                results.append(.success(file))
            } catch {
                results.append(.failure(file, error.localizedDescription))
            }
        }
        return results
    }
    
    // MARK: - File Watching (DispatchSource vnode)
    
    private var watchers: [URL: DispatchSourceFileSystemObject] = [:]
    var onFileChange: ((URL) -> Void)?
    
    func startWatching(_ url: URL) {
        guard watchers[url] == nil else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async { self?.onFileChange?(url) }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watchers[url] = source
    }
    
    func stopWatching(_ url: URL) {
        watchers[url]?.cancel()
        watchers.removeValue(forKey: url)
    }
    
    func stopAll() {
        watchers.values.forEach { $0.cancel() }
        watchers.removeAll()
    }
}

// MARK: - Supporting Types

struct DirectoryStatistics {
    var fileCount: Int = 0
    var folderCount: Int = 0
    var totalSize: Int64 = 0
    var categoryCounts: [FileCategory: Int] = [:]
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

enum BatchResult {
    case success(URL)
    case failure(URL, String)
}
