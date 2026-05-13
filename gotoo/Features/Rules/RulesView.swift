import SwiftUI
import SwiftData

struct RulesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FileRule.name) private var rules: [FileRule]
    @State private var selectedRule: FileRule?
    @State private var showingEditor = false
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("自动化规则")
                    .font(.headline)
                
                Text("(\(rules.filter(\.isEnabled).count)/\(rules.count) 启用)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // 监控开关
                Button {
                    appState.toggleMonitoring(rules: rules)
                } label: {
                    Label(
                        appState.isMonitoringEnabled ? "监控中" : "未启动",
                        systemImage: appState.isMonitoringEnabled ? "pause.circle.fill" : "play.circle"
                    )
                    .font(.caption)
                }
                .tint(appState.isMonitoringEnabled ? .green : nil)
                
                Divider().frame(height: 16)
                
                Picker("", selection: $selectedTab) {
                    Text("规则").tag(0)
                    Text("日志").tag(1)
                    Text("待确认").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Divider().frame(height: 16)
                
                Button(action: addRule) {
                    Image(systemName: "plus")
                }
                
                Button {
                    appState.showTemplatePanel = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
            }
            .padding()
            
            Divider()
            
            // 内容
            Group {
                if selectedTab == 0 {
                    rulesList
                } else if selectedTab == 1 {
                    MonitorLogView(log: appState.ruleMonitor.executionLog)
                } else {
                    pendingConfirmations
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showingEditor) {
            if let rule = selectedRule {
                RuleEditorView(rule: rule)
            }
        }
    }
    
    // MARK: - Rules List
    
    private var rulesList: some View {
        Group {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("暂无规则", systemImage: "gearshape")
                } description: {
                    Text("点击 + 添加自动化规则，或从模板创建")
                } actions: {
                    HStack {
                        Button("添加规则") { addRule() }
                            .buttonStyle(.borderedProminent)
                        Button("从模板创建") {
                            appState.showTemplatePanel = true
                        }
                    }
                }
            } else {
                List(selection: $selectedRule) {
                    ForEach(rules) { rule in
                        ruleRow(rule)
                            .tag(rule)
                            .contextMenu {
                                Button("立即执行") {
                                    appState.ruleMonitor.runRule(rule)
                                }
                                Button("复制规则") {
                                    let copy = FileRule(name: "\(rule.name) 副本", watchPath: rule.watchPath, conditions: rule.conditions, actions: rule.actions)
                                    copy.conditionLogic = rule.conditionLogic
                                    copy.isRecursive = rule.isRecursive
                                    copy.runMode = rule.runMode
                                    modelContext.insert(copy)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    modelContext.delete(rule)
                                }
                            }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    private func ruleRow(_ rule: FileRule) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(rule.name)
                        .font(.body)
                    if !rule.color.isEmpty {
                        Circle()
                            .fill(Color(hex: rule.color) ?? .accentColor)
                            .frame(width: 8, height: 8)
                    }
                    if rule.isRecursive {
                        Text("递归")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .background(.blue.opacity(0.1), in: Capsule())
                    }
                    Text(rule.runMode == "auto" ? "自动" : rule.runMode == "confirm" ? "需确认" : "手动")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(rule.runMode == "auto" ? .green.opacity(0.1) : .orange.opacity(0.1), in: Capsule())
                }
                
                Text(rule.watchPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                let conds = rule.conditions
                if !conds.isEmpty {
                    HStack(spacing: 4) {
                        if rule.conditionLogic == "any" {
                            Text("任一匹配")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        ForEach(conds.indices, id: \.self) { i in
                            Text(conds[i].kind.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.fill.tertiary, in: Capsule())
                        }
                    }
                }
                
                if rule.runCount > 0 {
                    Text("已运行 \(rule.runCount) 次" + (rule.lastRunDate.map { "，上次: \($0.formatted(.dateTime.month().day().hour().minute()))" } ?? ""))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            Circle()
                .fill(rule.isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 3)
    }
    
    // MARK: - Pending Confirmations
    
    private var pendingConfirmations: some View {
        Group {
            if appState.ruleMonitor.pendingConfirmations.isEmpty {
                ContentUnavailableView {
                    Label("无待确认操作", systemImage: "checkmark.circle")
                } description: {
                    Text("设置为「需确认」模式的规则匹配后，操作会出现在这里")
                }
            } else {
                List {
                    ForEach(appState.ruleMonitor.pendingConfirmations) { pending in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pending.rule.name)
                                    .font(.body)
                                Text(pending.file.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(pending.actions, id: \.kind) { action in
                                        Text(action.kind.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .background(.fill.tertiary, in: Capsule())
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button("执行") {
                                appState.ruleMonitor.confirmExecution(pending)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("跳过") {
                                appState.ruleMonitor.rejectExecution(pending)
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    private func addRule() {
        let rule = FileRule(name: "新规则", watchPath: appState.paneManager.activePane.currentDirectory.path)
        modelContext.insert(rule)
        selectedRule = rule
        showingEditor = true
    }
}

// MARK: - Rule Editor (增强版)

struct RuleEditorView: View {
    @Bindable var rule: FileRule
    @Environment(\.dismiss) private var dismiss
    @State private var newCondKind: RuleCondition.Kind = .extensionMatch
    @State private var newCondValue = ""
    @State private var newCondNegated = false
    @State private var newActKind: RuleAction.Kind = .moveTo
    @State private var newActParam = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("编辑规则").font(.title2)
                
                Form {
                    Section("基本信息") {
                        TextField("规则名称", text: $rule.name)
                        
                        HStack {
                            TextField("监控路径", text: $rule.watchPath)
                            Button("选择...") {
                                let panel = NSOpenPanel()
                                panel.canChooseDirectories = true
                                panel.canChooseFiles = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    rule.watchPath = url.path
                                }
                            }
                        }
                        
                        Toggle("启用", isOn: $rule.isEnabled)
                        Toggle("递归子文件夹", isOn: $rule.isRecursive)
                        
                        Picker("条件逻辑", selection: $rule.conditionLogic) {
                            Text("全部满足 (AND)").tag("all")
                            Text("任一满足 (OR)").tag("any")
                        }
                        .pickerStyle(.radioGroup)
                        
                        Picker("运行模式", selection: $rule.runMode) {
                            Text("自动执行").tag("auto")
                            Text("需要确认").tag("confirm")
                            Text("仅手动").tag("manual")
                        }
                        
                        TextField("描述", text: $rule.descriptionText, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    
                    Section("条件") {
                        ForEach(rule.conditions.indices, id: \.self) { i in
                            HStack {
                                if rule.conditions[i].isNegated {
                                    Text("非")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                }
                                Label(rule.conditions[i].kind.rawValue, systemImage: "line.3.horizontal.decrease")
                                    .font(.caption)
                                Text(rule.conditions[i].value)
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button(role: .destructive) { rule.conditions.remove(at: i) } label: {
                                    Image(systemName: "minus.circle").font(.caption)
                                }
                            }
                        }
                        
                        HStack {
                            Picker("", selection: $newCondKind) {
                                ForEach(RuleCondition.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .frame(width: 120)
                            TextField("值", text: $newCondValue)
                            Toggle("取反", isOn: $newCondNegated)
                                .toggleStyle(.checkbox)
                            Button("添加") {
                                guard !newCondValue.isEmpty || isValuelessCondition(newCondKind) else { return }
                                var c = rule.conditions
                                c.append(.init(kind: newCondKind, value: newCondValue, isNegated: newCondNegated))
                                rule.conditions = c
                                newCondValue = ""
                                newCondNegated = false
                            }
                        }
                    }
                    
                    Section("动作") {
                        ForEach(rule.actions.indices, id: \.self) { i in
                            HStack {
                                Label(rule.actions[i].kind.rawValue, systemImage: "bolt")
                                    .font(.caption)
                                Text(rule.actions[i].parameter)
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button(role: .destructive) { rule.actions.remove(at: i) } label: {
                                    Image(systemName: "minus.circle").font(.caption)
                                }
                            }
                        }
                        
                        HStack {
                            Picker("", selection: $newActKind) {
                                ForEach(RuleAction.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .frame(width: 120)
                            if needsParameter(newActKind) {
                                HStack {
                                    TextField("参数", text: $newActParam)
                                    if newActKind == .moveTo || newActKind == .copyTo {
                                        Button("...") {
                                            let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false
                                            if p.runModal() == .OK, let u = p.url { newActParam = u.path }
                                        }
                                    }
                                }
                            }
                            Button("添加") {
                                guard !newActParam.isEmpty || !needsParameter(newActKind) else { return }
                                var a = rule.actions
                                a.append(.init(kind: newActKind, parameter: newActParam))
                                rule.actions = a
                                newActParam = ""
                            }
                        }
                    }
                    
                    Section("定时") {
                        if rule.schedule == nil {
                            Button("设置定时执行") {
                                rule.schedule = ScheduleConfig(interval: 60)
                            }
                        } else {
                            HStack {
                                Text("间隔(分钟)")
                                TextField("分钟", value: Binding(
                                    get: { rule.schedule?.interval ?? 60 },
                                    set: { var s = rule.schedule ?? ScheduleConfig(interval: 60); s.interval = $0; rule.schedule = s }
                                ), format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                            Button("移除定时") {
                                rule.schedule = nil
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
                .formStyle(.grouped)
                
                HStack {
                    Spacer()
                    Button("完成") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 550)
    }
    
    private func needsParameter(_ kind: RuleAction.Kind) -> Bool {
        switch kind {
        case .reveal, .notify: return false
        default: return true
        }
    }
    
    private func isValuelessCondition(_ kind: RuleCondition.Kind) -> Bool {
        switch kind {
        case .isImage, .isVideo, .isAudio, .isDocument, .isArchive, .isCode, .isPDF,
             .isHidden, .modifiedToday, .modifiedThisWeek, .modifiedThisMonth,
             .createdToday, .createdThisWeek, .createdThisMonth:
            return true
        default: return false
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255.0,
                  green: Double((rgb >> 8) & 0xFF) / 255.0,
                  blue: Double(rgb & 0xFF) / 255.0)
    }
}
