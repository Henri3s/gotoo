import SwiftUI
import SwiftData

struct RulesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [FileRule]
    @State private var selectedRule: FileRule?
    @State private var showingEditor = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("自动化规则")
                    .font(.headline)
                Spacer()
                Button(action: addRule) {
                    Image(systemName: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // Rule List
            if rules.isEmpty {
                ContentUnavailableView("暂无规则", systemImage: "gearshape", description: Text("点击 + 添加自动化规则"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedRule) {
                    ForEach(rules) { rule in
                        RuleRow(rule: rule)
                            .tag(rule)
                            .contextMenu {
                                Button("删除", role: .destructive) {
                                    modelContext.delete(rule)
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 280, minHeight: 400)
        .sheet(isPresented: $showingEditor) {
            if let rule = selectedRule {
                RuleEditorView(rule: rule)
            }
        }
    }
    
    private func addRule() {
        let rule = FileRule(name: "新规则", watchPath: appState.currentDirectory.path)
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
                Text(rule.name)
                    .font(.body)
                Text(rule.watchPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Circle()
                .fill(rule.isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
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
                TextField("监控路径", text: $rule.watchPath)
                Toggle("启用", isOn: $rule.isEnabled)
                
                // Conditions
                Section("条件") {
                    ForEach(rule.conditions.indices, id: \.self) { i in
                        HStack {
                            Text(rule.conditions[i].kind.rawValue)
                            Text(rule.conditions[i].value)
                            Spacer()
                            Button(role: .destructive) {
                                rule.conditions.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                        }
                    }
                    
                    HStack {
                        Picker("类型", selection: $newConditionKind) {
                            ForEach(RuleCondition.Kind.allCases, id: \.self) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
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
                
                // Actions
                Section("动作") {
                    ForEach(rule.actions.indices, id: \.self) { i in
                        HStack {
                            Text(rule.actions[i].kind.rawValue)
                            Text(rule.actions[i].parameter)
                            Spacer()
                            Button(role: .destructive) {
                                rule.actions.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                        }
                    }
                    
                    HStack {
                        Picker("类型", selection: $newActionKind) {
                            ForEach(RuleAction.Kind.allCases, id: \.self) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                        TextField("参数", text: $newActionParam)
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
        .frame(minWidth: 500, minHeight: 500)
    }
}
