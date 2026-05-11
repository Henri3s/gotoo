import SwiftUI
import SwiftData

struct RulesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FileRule.name) private var rules: [FileRule]
    @State private var selectedRule: FileRule?
    @State private var showingEditor = false
    @State private var selectedTab = 0  // 0 = rules, 1 = log
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("自动化规则")
                    .font(.headline)
                
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
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                
                Divider().frame(height: 16)
                
                Button(action: addRule) {
                    Image(systemName: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // 内容
            Group {
                if selectedTab == 0 {
                    rulesList
                } else {
                    MonitorLogView(log: appState.ruleMonitor.executionLog)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 450)
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
                    Text("点击 + 添加自动化规则")
                } actions: {
                    Button("添加规则") { addRule() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selectedRule) {
                    ForEach(rules) { rule in
                        ruleRow(rule)
                            .tag(rule)
                            .contextMenu {
                                Button("立即执行") {
                                    appState.ruleMonitor.runAllOnce(rules: [rule])
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
                Text(rule.name)
                    .font(.body)
                Text(rule.watchPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // 条件标签
                let conds = rule.conditions
                if !conds.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(conds.indices, id: \.self) { i in
                            Text(conds[i].kind.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.fill.tertiary, in: Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            // 状态指示
            Circle()
                .fill(rule.isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 3)
    }
    
    private func addRule() {
        let rule = FileRule(name: "新规则", watchPath: appState.paneManager.activePane.currentDirectory.path)
        modelContext.insert(rule)
        selectedRule = rule
        showingEditor = true
    }
}

// MARK: - Rule Editor

struct RuleEditorView: View {
    @Bindable var rule: FileRule
    @Environment(\.dismiss) private var dismiss
    @State private var newCondKind: RuleCondition.Kind = .extensionMatch
    @State private var newCondValue = ""
    @State private var newActKind: RuleAction.Kind = .moveTo
    @State private var newActParam = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("编辑规则").font(.title2)
            
            Form {
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
                
                Section("条件") {
                    ForEach(rule.conditions.indices, id: \.self) { i in
                        HStack {
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
                        .frame(width: 140)
                        TextField("值", text: $newCondValue)
                        Button("添加") {
                            guard !newCondValue.isEmpty else { return }
                            var c = rule.conditions; c.append(.init(kind: newCondKind, value: newCondValue))
                            rule.conditions = c; newCondValue = ""
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
                        .frame(width: 100)
                        if newActKind == .moveTo || newActKind == .copyTo {
                            HStack {
                                TextField("目标", text: $newActParam)
                                Button("...") {
                                    let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false
                                    if p.runModal() == .OK, let u = p.url { newActParam = u.path }
                                }
                            }
                        } else {
                            TextField("参数", text: $newActParam)
                        }
                        Button("添加") {
                            guard !newActParam.isEmpty else { return }
                            var a = rule.actions; a.append(.init(kind: newActKind, parameter: newActParam))
                            rule.actions = a; newActParam = ""
                        }
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
        .frame(minWidth: 550, minHeight: 500)
    }
}
