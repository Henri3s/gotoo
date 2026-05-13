import SwiftUI
import SwiftData

/// 文件夹配置视图 — 为特定文件夹设置自定义 AI 提示词和快捷操作
struct FolderConfigView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var configs: [FolderConfig]
    @Query private var skills: [FileSkill]
    @State private var selectedConfig: FolderConfig?
    @State private var isNewConfig = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("文件夹配置")
                    .font(.title2.bold())
                Spacer()
                Button {
                    addConfig()
                } label: {
                    Label("添加文件夹", systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            HSplitView {
                // 左侧：文件夹列表
                List(selection: $selectedConfig) {
                    ForEach(configs) { config in
                        folderRow(config)
                            .tag(config)
                            .contextMenu {
                                Button("删除", role: .destructive) {
                                    modelContext.delete(config)
                                }
                            }
                    }
                }
                .frame(minWidth: 200)
                
                // 右侧：配置详情
                if let config = selectedConfig {
                    configEditor(config)
                } else {
                    ContentUnavailableView {
                        Label("选择文件夹", systemImage: "folder")
                    } description: {
                        Text("选择左侧的文件夹进行配置，或添加新的文件夹")
                    }
                }
            }
        }
    }
    
    // MARK: - Folder Row
    
    private func folderRow(_ config: FolderConfig) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: config.folderPath).lastPathComponent)
                    .font(.body)
                Text(config.folderPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if config.isAutoEnabled {
                Image(systemName: "bolt.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Config Editor
    
    private func configEditor(_ config: FolderConfig) -> some View {
        @Bindable var cfg = config
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 基本信息
                GroupBox("基本信息") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("文件夹路径:")
                                .frame(width: 80, alignment: .trailing)
                            TextField("路径", text: $cfg.folderPath)
                            Button("选择...") {
                                let panel = NSOpenPanel()
                                panel.canChooseDirectories = true
                                panel.canChooseFiles = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    cfg.folderPath = url.path
                                }
                            }
                        }
                        
                        Toggle("启用自动 AI 处理", isOn: $cfg.isAutoEnabled)
                    }
                }
                
                // 自定义 AI 提示词
                GroupBox("AI 提示词") {
                    VStack(spacing: 8) {
                        Text("当在该文件夹中触发 AI 操作时，会使用以下提示词作为系统提示")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $cfg.customPrompt)
                            .font(.body)
                            .frame(minHeight: 120)
                            .border(.separator)
                    }
                }
                
                // 自动执行提示词
                GroupBox("自动执行提示词") {
                    VStack(spacing: 8) {
                        Text("当文件夹有新文件时，自动使用以下提示词处理")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $cfg.autoPrompt)
                            .font(.body)
                            .frame(minHeight: 80)
                            .border(.separator)
                    }
                }
                
                // 关联技能
                GroupBox("关联技能") {
                    VStack(alignment: .leading, spacing: 8) {
                        let linkedSkills = cfg.linkedSkills
                        if !linkedSkills.isEmpty {
                            ForEach(linkedSkills, id: \.self) { skillName in
                                HStack {
                                    Image(systemName: "star")
                                        .foregroundStyle(Color.accentColor)
                                    Text(skillName)
                                        .font(.body)
                                    Spacer()
                                    Button {
                                        var skills = cfg.linkedSkills
                                        skills.removeAll { $0 == skillName }
                                        cfg.linkedSkills = skills
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        
                        Menu("添加技能") {
                            ForEach(BuiltInSkills.allBuiltIn) { skill in
                                Button(skill.name) {
                                    var current = cfg.linkedSkills
                                    if !current.contains(skill.name) {
                                        current.append(skill.name)
                                        cfg.linkedSkills = current
                                    }
                                }
                            }
                            
                            Divider()
                            
                            ForEach(skills) { skill in
                                Button(skill.name) {
                                    var current = cfg.linkedSkills
                                    if !current.contains(skill.name) {
                                        current.append(skill.name)
                                        cfg.linkedSkills = current
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 快捷操作
                GroupBox("自定义快捷操作") {
                    VStack(alignment: .leading, spacing: 8) {
                        let actions = cfg.quickActions
                        ForEach(actions) { action in
                            HStack {
                                Image(systemName: action.icon)
                                    .foregroundStyle(action.isDestructive ? .red : Color.accentColor)
                                Text(action.name)
                                    .font(.body)
                                Spacer()
                                Button {
                                    var acts = cfg.quickActions
                                    acts.removeAll { $0.id == action.id }
                                    cfg.quickActions = acts
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        
                        Button("添加快捷操作") {
                            var acts = cfg.quickActions
                            acts.append(QuickAction(name: "新操作", prompt: ""))
                            cfg.quickActions = acts
                        }
                    }
                }
                
                // 排除模式
                GroupBox("排除规则") {
                    VStack(spacing: 8) {
                        Text("排除匹配以下关键词的文件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        let excludes = cfg.excludes
                        ForEach(excludes, id: \.self) { pattern in
                            HStack {
                                Text(pattern)
                                    .font(.body)
                                Spacer()
                                Button {
                                    var exc = cfg.excludes
                                    exc.removeAll { $0 == pattern }
                                    cfg.excludes = exc
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                
                // 文件大小限制
                GroupBox("处理限制") {
                    HStack {
                        Text("最大文件大小:")
                        TextField("字节", value: $cfg.maxFileSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        Text(ByteCountFormatter.string(fromByteCount: cfg.maxFileSize, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func addConfig() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "选择文件夹"
        
        if panel.runModal() == .OK, let url = panel.url {
            let config = FolderConfig(folderPath: url.path)
            modelContext.insert(config)
            selectedConfig = config
        }
    }
}
