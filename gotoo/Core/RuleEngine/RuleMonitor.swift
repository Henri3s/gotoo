import Foundation
import Observation
import UserNotifications

/// 规则监控器 — 后台监控文件夹变更并自动执行规则
@Observable
@MainActor
final class RuleMonitor {
    private var timer: Timer?
    private var fileSources: [URL: DispatchSourceFileSystemObject] = [:]
    var executionLog: [ExecutionEntry] = []
    var pendingConfirmations: [PendingExecution] = []
    
    private let ruleEngine = RuleEngine()
    
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
        
        for rule in rules where rule.isEnabled {
            let url = URL(fileURLWithPath: rule.watchPath)
            startFileWatch(url)
        }
        
        startScheduleTimer(rules: rules)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        for source in fileSources.values { source.cancel() }
        fileSources.removeAll()
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
        
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleFileChange(at: url)
            }
        }
        
        source.setCancelHandler { close(fd) }
        source.resume()
        fileSources[url] = source
    }
    
    private func handleFileChange(at url: URL) {
        // 通知 UI 有变更
        // TODO: 查找匹配该路径的规则并执行
    }
    
    // MARK: - Rule Execution
    
    func runRule(_ rule: FileRule, in directory: URL? = nil) {
        let dir = directory ?? URL(fileURLWithPath: rule.watchPath)
        let ruleEngine = RuleEngine()
        
        guard let _ = try? FileEngine().contents(of: dir),
              let matched = try? ruleEngine.apply(rules: [rule], toDirectory: dir) else { return }
        
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
        
        // 捕获规则引用（闭包中只用于检查 schedule）
        // FileRule 是 @Model (SwiftData)，在 @MainActor 上下文中使用是安全的
        // non Sendable warning: FileRule 是 @Model，跨 actor 传递是安全的
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
