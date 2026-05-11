import SwiftUI
import Observation

/// 面板布局
enum PaneLayout: String, CaseIterable, Identifiable {
    case single = "单栏"
    case dual = "双栏"
    case triple = "三栏"
    
    var id: String { rawValue }
    var count: Int { switch self { case .single: 1; case .dual: 2; case .triple: 3 } }
}

/// 单个面板的状态
@Observable
@MainActor
final class PaneState: Identifiable {
    let id = UUID()
    var currentDirectory: URL
    var files: [FileItem] = []
    var selectedFiles: Set<URL> = []
    var isLoading = false
    var errorMessage: String?
    
    init(directory: URL) {
        self.currentDirectory = directory
    }
    
    func navigateTo(_ url: URL) {
        currentDirectory = url
        selectedFiles.removeAll()
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
        if activePaneIndex >= panes.count { activePaneIndex = 0 }
    }
    
    func focusPane(index: Int) {
        guard index < panes.count else { return }
        activePaneIndex = index
    }
    
    func nextPane() {
        activePaneIndex = (activePaneIndex + 1) % min(panes.count, layout.count)
    }
}
