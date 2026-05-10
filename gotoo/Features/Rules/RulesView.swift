import SwiftUI
import SwiftData

struct RulesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [FileRule]
    @State private var selectedRule: FileRule?
    @State private var showingEditor = false
    @State private var showLog = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("自动化规则")
                    .font(.headline)
                
                Spacer()
                
                // 监控开关
                Toggle(isOn: Binding(
                    get: { appState.isMonitoringEnabled },
                    set: { _ in appState.toggleMonitoring(rules: rules) }
                )) {
                    Label(
                        appState.isMonitoringEnabled ? "监控中" : "已暂停",
                        systemImage: appState.isMonitoringEnabled ? "pause.circle.fill" : "play.circle"
                    )
                    .font(.caption)
                }
                .toggleStyle(.button)
                
                Button { showLog.toggle() } label: {
                    Image(systemName: "list.bullet")
                }
                
                Button(action: addRule) {
                    Image(systemName: "plus")
                }
            }
            .padding()
            
            Divider()
            
            if showLog {
                MonitorLogView(log: appState.ruleMonitor.executionLog)
            } else if rules.isEmpty {
                ContentUnavailableView("暂无规则", systemImage: "gearshape", description: Text("点击 + 添加自动化规则"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedRule) {
                    ForEach(rules) { rule in
                        RuleRow(rule: rule)
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
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 500, minHeight: 450)
        .sheet(isPresented: $showingEditor) {
            if let rule = selectedRule {
                RuleEditorView(rule: rule)
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

struct RuleRow: View {
    let rule: FileRule
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name).font(.body)
                Text(rule.watchPath)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !rule.conditions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(rule.conditions.indices, id: \.self) { i in
                            Text(rule.conditions[i].kind.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.tertiary, in: Capsule())
                        }
                    }
                }
            }
            Spacer()
            Circle()
                .fill(rule.isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

struct RuleEditorView: View {
    @Bindable var rule: FileRule
    @Environment(\.dismiss) private var dismiss
    @State private var newConditionKind: RuleCondition.Kind = .extensionMatch
    @State private var newConditionValue = ""
    @State private var newActionKind: RuleAction.Kind = .moveTo
    @State private var newActionParam = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("编辑规则").font(.title2)
            
            Form {
                TextField("规则名称", text: $rule.name)
                
                HStack {
                    TextField("监控路径", text: $rule.watchPath)
                    Button("选择") {
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
                            Text(rule.conditions[i].kind.rawValue)
                                .font(.caption)
                            Text(rule.conditions[i].value)
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                rule.conditions.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle").font(.caption)
                            }
                        }
                    }
                    
                    HStack {
                        Picker("类型", selection: $newConditionKind) {
                            ForEach(RuleCondition.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        TextField("值", text: $newConditionValue)
                        Button("添加") {
                            guard !newConditionValue.isEmpty else { return }
                            var conditions = rule.conditions
                            conditions.append(RuleCondition(kind: newConditionKind, value: newConditionValue))
                            rule.conditions = conditions
                            newConditionValue = ""
                        }
                    }
                }
                
                Section("动作") {
                    ForEach(rule.actions.indices, id: \.self) { i in
                        HStack {
                            Text(rule.actions[i].kind.rawValue).font(.caption)
                            Text(rule.actions[i].parameter).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                rule.actions.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle").font(.caption)
                            }
                        }
                    }
                    
                    HStack {
                        Picker("类型", selection: $newActionKind) {
                            ForEach(RuleAction.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        if newActionKind == .moveTo || newActionKind == .copyTo {
                            HStack {
                                TextField("目标路径", text: $newActionParam)
                                Button("选择") {
                                    let panel = NSOpenPanel()
                                    panel.canChooseDirectories = true
                                    panel.canChooseFiles = false
                                    if panel.runModal() == .OK, let url = panel.url {
                                        newActionParam = url.path
                                    }
                                }
                            }
                        } else {
                            TextField("参数", text: $newActionParam)
                        }
                        Button("添加") {
                            guard !newActionParam.isEmpty else { return }
                            var actions = rule.actions
                            actions.append(RuleAction(kind: newActionKind, parameter: newActionParam))
                            rule.actions = actions
                            newActionParam = ""
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
