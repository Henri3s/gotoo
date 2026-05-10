import Foundation
import Observation

@Observable
@MainActor
final class FileEngine {
    private let fm = FileManager.default
    
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
    
    func move(from source: URL, to directory: URL) throws {
        try fm.moveItem(at: source, to: directory.appendingPathComponent(source.lastPathComponent))
    }
    
    func copy(from source: URL, to directory: URL) throws {
        try fm.copyItem(at: source, to: directory.appendingPathComponent(source.lastPathComponent))
    }
    
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
    
    // MARK: - File Watching (DispatchSource vnode)
    
    private var watchers: [URL: DispatchSourceFileSystemObject] = [:]
    var onFileChange: ((URL) -> Void)?
    
    func startWatching(_ url: URL) {
        guard watchers[url] == nil else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.onFileChange?(url) }
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
    
    static let favorites: [(String, URL)] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("主目录", home),
            ("桌面", home.appendingPathComponent("Desktop")),
            ("文稿", home.appendingPathComponent("Documents")),
            ("下载", home.appendingPathComponent("Downloads")),
            ("图片", home.appendingPathComponent("Pictures")),
            ("音乐", home.appendingPathComponent("Music")),
            ("影片", home.appendingPathComponent("Movies")),
        ]
    }()
}
