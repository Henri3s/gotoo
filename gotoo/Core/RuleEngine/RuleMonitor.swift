import Foundation
import AppKit
import Observation

/// 后台规则监控器 — 持续监听文件夹并自动执行匹配规则
@Observable
@MainActor
final class RuleMonitor {
    var isRunning = false
    var executionLog: [ExecutionEntry] = []
    
    struct ExecutionEntry: Identifiable {
        let id = UUID()
        let date: Date
        let ruleName: String
        let fileName: String
        let action: String
        var success: Bool
        var errorMessage: String?
    }
    
    private var watchers: [String: DispatchSourceFileSystemObject] = [:]
    private let fileEngine = FileEngine()
    private let ruleEngine = RuleEngine()
    private var watchedPaths: Set<String> = []
    
    /// 启动监控所有已启用规则的文件夹
    func startMonitoring(rules: [FileRule]) {
        stopMonitoring()
        
        let enabledRules = rules.filter(\.isEnabled)
        let paths = Set(enabledRules.map(\.watchPath))
        
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write],
                queue: .global(qos: .utility)
            )
            
            // 捕获值的副本用于后台线程
            let rulesCopy = enabledRules.filter { $0.watchPath == path }
            let engine = ruleEngine
            let fe = fileEngine
            
            source.setEventHandler {
                // 延迟 1 秒去重（文件系统事件可能密集触发）
                Thread.sleep(forTimeInterval: 1.0)
                
                Task { @MainActor in
                    self.runRules(rulesCopy, in: url)
                }
            }
            
            source.setCancelHandler { close(fd) }
            source.resume()
            watchers[path] = source
        }
        
        watchedPaths = paths
        isRunning = true
        
        // 首次扫描
        for path in paths {
            runRules(enabledRules.filter { $0.watchPath == path }, in: URL(fileURLWithPath: path))
        }
    }
    
    func stopMonitoring() {
        watchers.values.forEach { $0.cancel() }
        watchers.removeAll()
        watchedPaths.removeAll()
        isRunning = false
    }
    
    /// 手动触发一次全量扫描
    func runAllOnce(rules: [FileRule]) {
        let enabled = rules.filter(\.isEnabled)
        let paths = Set(enabled.map(\.watchPath))
        for path in paths {
            runRules(enabled.filter { $0.watchPath == path }, in: URL(fileURLWithPath: path))
        }
    }
    
    // MARK: - Private
    
    private func runRules(_ rules: [FileRule], in directory: URL) {
        let files: [FileItem]
        do {
            files = try fileEngine.contents(of: directory)
        } catch {
            return
        }
        
        for file in files where !file.isDirectory {
            for rule in rules where rule.matches(file: file) {
                for action in rule.actions {
                    executeAction(action, on: file, ruleName: rule.name)
                }
            }
        }
    }
    
    private func executeAction(_ action: RuleAction, on file: FileItem, ruleName: String) {
        var entry = ExecutionEntry(
            date: Date(),
            ruleName: ruleName,
            fileName: file.name,
            action: action.kind.rawValue,
            success: false
        )
        
        do {
            switch action.kind {
            case .moveTo:
                let dest = URL(fileURLWithPath: action.parameter)
                try fileEngine.move(from: file.url, to: dest)
            case .copyTo:
                let dest = URL(fileURLWithPath: action.parameter)
                try fileEngine.copy(from: file.url, to: dest)
            case .rename:
                _ = try fileEngine.rename(file.url, to: action.parameter)
            case .trash:
                try fileEngine.trash(file.url)
            case .reveal:
                NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
            }
            entry.success = true
        } catch {
            entry.success = false
            entry.errorMessage = error.localizedDescription
        }
        
        executionLog.append(entry)
        
        // 只保留最近 500 条
        if executionLog.count > 500 {
            executionLog.removeFirst(executionLog.count - 500)
        }
    }
}
