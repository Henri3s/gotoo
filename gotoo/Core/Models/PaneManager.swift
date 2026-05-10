import SwiftUI
import Observation

/// 管理面板布局（单栏/双栏/三栏）
enum PaneLayout: String, CaseIterable, Identifiable {
    case single = "单栏"
    case dual = "双栏"
    case triple = "三栏"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .single: return "rectangle"
        case .dual: return "rectangle.split.1x2"
        case .triple: return "rectangle.split.1x3"
        }
    }
    
    var count: Int {
        switch self {
        case .single: return 1
        case .dual: return 2
        case .triple: return 3
        }
    }
}

/// 单个面板的状态
@Observable
@MainActor
final class PaneState: Identifiable {
    let id = UUID()
    var currentDirectory: URL
    var files: [FileItem] = []
    var selectedFiles: Set<URL> = []
    var searchQuery = ""
    var isLoading = false
    var errorMessage: String?
    var tabs: [TabState]
    var activeTabId: UUID
    
    struct TabState: Identifiable {
        let id = UUID()
        var directory: URL
        var title: String
        
        init(directory: URL) {
            self.directory = directory
            self.title = directory.lastPathComponent
        }
    }
    
    init(directory: URL) {
        self.currentDirectory = directory
        let initialTab = TabState(directory: directory)
        self.tabs = [initialTab]
        self.activeTabId = initialTab.id
    }
    
    var activeTabIndex: Int {
        tabs.firstIndex(where: { $0.id == activeTabId }) ?? 0
    }
    
    func addTab(directory: URL) {
        let tab = TabState(directory: directory)
        tabs.append(tab)
        activeTabId = tab.id
        currentDirectory = directory
    }
    
    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        tabs.removeAll(where: { $0.id == id })
        if activeTabId == id, let first = tabs.first {
            activeTabId = first.id
            currentDirectory = first.directory
        }
    }
    
    func switchTab(id: UUID) {
        activeTabId = id
        if let tab = tabs.first(where: { $0.id == id }) {
            currentDirectory = tab.directory
        }
    }
    
    func navigateTo(_ url: URL) {
        currentDirectory = url
        selectedFiles.removeAll()
        // Update active tab
        if let idx = tabs.firstIndex(where: { $0.id == activeTabId }) {
            tabs[idx].directory = url
            tabs[idx].title = url.lastPathComponent
        }
    }
}

/// 全局面板管理
@Observable
@MainActor
final class PaneManager {
    var layout: PaneLayout = .dual
    var panes: [PaneState] = []
    var activePaneIndex: Int = 0
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let downloads = home.appendingPathComponent("Downloads")
        panes = [PaneState(directory: home), PaneState(directory: downloads)]
    }
    
    var activePane: PaneState { panes[activePaneIndex] }
    
    func setLayout(_ newLayout: PaneLayout) {
        layout = newLayout
        let home = FileManager.default.homeDirectoryForCurrentUser
        while panes.count < newLayout.count {
            panes.append(PaneState(directory: home))
        }
        if activePaneIndex >= panes.count {
            activePaneIndex = 0
        }
    }
    
    func focusPane(index: Int) {
        guard index < panes.count else { return }
        activePaneIndex = index
    }
    
    func nextPane() {
        activePaneIndex = (activePaneIndex + 1) % panes.count
    }
}
