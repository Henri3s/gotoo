import Foundation
import Observation
import UserNotifications

/// 规则监控器 — 后台监控文件夹变更并自动执行规则
@Observable
@MainActor
final class RuleMonitor {
    private var timer: Timer?
    private var fileSources: [URL: DispatchSourceFileSystemObject] = [:]
    private var debounceTask: Task<Void, Never>?
    var executionLog: [ExecutionEntry] = []
    var pendingConfirmations: [PendingExecution] = []
    
    private let ruleEngine = RuleEngine()
    private let fileEngine = FileEngine()
    /// 当前活跃的规则引用
    private var activeRules: [FileRule] = []
    
    // MARK: - Types
    
    struct ExecutionEntry: Identifiable {
        let id = UUID()
        let date: Date
        let ruleName: String
        let fileName: String
        let action: String
        let success: Bool
        var errorMessage: String?
    }
    
    struct PendingExecution: Identifiable {
        let id = UUID()
        let rule: FileRule
        let file: FileItem
        let actions: [RuleAction]
    }
    
    // MARK: - Monitoring
    
    func startMonitoring(rules: [FileRule]) {
        stopMonitoring()
        activeRules = rules.filter { $0.isEnabled }
        
        for rule in activeRules {
            let url = URL(fileURLWithPath: rule.watchPath)
            startFileWatch(url)
        }
        
        startScheduleTimer(rules: activeRules)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        for source in fileSources.values { source.cancel() }
        fileSources.removeAll()
        debounceTask?.cancel()
        debounceTask = nil
        activeRules = []
    }
    
    /// 手动执行所有规则一次
    func runAllOnce(rules: [FileRule]) {
        for rule in rules where rule.isEnabled {
            let directory = URL(fileURLWithPath: rule.watchPath)
            runRule(rule, in: directory)
        }
    }
    
    // MARK: - File Watch
    
    private func startFileWatch(_ url: URL) {
        guard fileSources[url] == nil else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write],
            queue: .global(qos: .utility)
        )
        
        // 捕获 URL 值（不是引用），安全用于跨线程
        let watchedURL = url
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleFileChange(at: watchedURL)
            }
        }
        
        source.setCancelHandler { close(fd) }
        source.resume()
        fileSources[url] = source
    }
    
    /// 文件变化处理 — 1 秒防抖后执行匹配规则
    private func handleFileChange(at url: URL) {
        // 通知 UI 刷新文件列表
        NotificationCenter.default.post(name: .fileSystemChanged, object: url)
        
        // 防抖：多次快速事件合并为一次执行
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            executeMatchingRules(for: url)
        }
    }
    
    /// 查找并执行匹配该路径的规则
    private func executeMatchingRules(for changedURL: URL) {
        let matchingRules = activeRules.filter { rule in
            guard rule.isEnabled else { return false }
            let watchURL = URL(fileURLWithPath: rule.watchPath)
            return changedURL.path.hasPrefix(watchURL.path)
        }
        
        guard !matchingRules.isEmpty else { return }
        
        do {
            let files = try fileEngine.contents(of: changedURL)
            for rule in matchingRules {
                for file in files {
                    if rule.matches(file: file) {
                        let actions = rule.actions
                        switch rule.runMode {
                        case "confirm":
                            pendingConfirmations.append(PendingExecution(rule: rule, file: file, actions: actions))
                        case "manual":
                            break
                        default: // "auto"
                            executeActions(actions, for: rule, on: file)
                        }
                    }
                }
            }
        } catch {
            // 目录读取失败，静默忽略
        }
    }
    
    // MARK: - Rule Execution
    
    func runRule(_ rule: FileRule, in directory: URL? = nil) {
        let dir = directory ?? URL(fileURLWithPath: rule.watchPath)
        
        guard let matched = try? ruleEngine.apply(rules: [rule], toDirectory: dir) else { return }
        
        for (matchedRule, file) in matched {
            let actions = matchedRule.actions
            
            switch matchedRule.runMode {
            case "confirm":
                pendingConfirmations.append(PendingExecution(rule: matchedRule, file: file, actions: actions))
            case "manual":
                break
            default: // "auto"
                executeActions(actions, for: matchedRule, on: file)
            }
        }
    }
    
    /// 执行一组动作
    func executeActions(_ actions: [RuleAction], for rule: FileRule, on file: FileItem) {
        for action in actions {
            do {
                let msg = try ruleEngine.execute(action: action, on: file)
                executionLog.append(ExecutionEntry(
                    date: Date(),
                    ruleName: rule.name,
                    fileName: file.name,
                    action: msg,
                    success: true
                ))
            } catch {
                executionLog.append(ExecutionEntry(
                    date: Date(),
                    ruleName: rule.name,
                    fileName: file.name,
                    action: action.kind.rawValue,
                    success: false,
                    errorMessage: error.localizedDescription
                ))
            }
        }
        
        rule.lastRunDate = Date()
        rule.runCount += 1
        
        if executionLog.count > 500 {
            executionLog = Array(executionLog.suffix(500))
        }
        
        // 通知 UI 文件系统已变更
        NotificationCenter.default.post(name: .fileSystemChanged, object: file.url)
    }
    
    func confirmExecution(_ pending: PendingExecution) {
        executeActions(pending.actions, for: pending.rule, on: pending.file)
        pendingConfirmations.removeAll { $0.id == pending.id }
    }
    
    func rejectExecution(_ pending: PendingExecution) {
        pendingConfirmations.removeAll { $0.id == pending.id }
    }
    
    // MARK: - Schedule Timer
    
    private func startScheduleTimer(rules: [FileRule]) {
        timer?.invalidate()
        
        let scheduledRules = rules.filter { $0.schedule != nil }
        guard !scheduledRules.isEmpty else { return }
        
        // FileRule 是 @Model (SwiftData)，在 @MainActor 上下文中使用是安全的
        let capturedRules = scheduledRules
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.checkSchedules(rules: capturedRules)
            }
        }
    }
    
    private func checkSchedules(rules: [FileRule]) {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMinutes = currentHour * 60 + currentMinute
        
        for rule in rules {
            guard let schedule = rule.schedule else { continue }
            
            // 检查星期
            if let days = schedule.daysOfWeek {
                let weekday = calendar.component(.weekday, from: now)
                guard days.contains(weekday) else { continue }
            }
            
            // 检查时间窗口
            if let startStr = schedule.startTime, let endStr = schedule.endTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                guard let startDate = formatter.date(from: startStr),
                      let endDate = formatter.date(from: endStr) else { continue }
                let startMinutes = calendar.component(.hour, from: startDate) * 60 + calendar.component(.minute, from: startDate)
                let endMinutes = calendar.component(.hour, from: endDate) * 60 + calendar.component(.minute, from: endDate)
                guard currentTotalMinutes >= startMinutes && currentTotalMinutes <= endMinutes else { continue }
            }
            
            // 检查间隔
            if let lastRun = rule.lastRunDate {
                let elapsed = now.timeIntervalSince(lastRun) / 60
                if elapsed < Double(schedule.interval) { continue }
            }
            
            // 执行规则
            runRule(rule)
        }
    }
}
