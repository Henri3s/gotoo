import SwiftUI
import SwiftData

/// 技能浏览器 — 查看、使用、创建文件处理技能
struct SkillBrowserView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var skills: [FileSkill]
    @State private var selectedCategory = "全部"
    @State private var searchText = ""
    @State private var isExecuting = false
    @State private var executionResult: String?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("文件处理技能")
                    .font(.title2.bold())
                Spacer()
                
                TextField("搜索技能...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Button {
                    addSkill()
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // 分类筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip("全部")
                    ForEach(categories, id: \.self) { cat in
                        categoryChip(cat)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // 技能网格
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    // 内置技能
                    ForEach(filteredSkills) { skill in
                        skillCard(skill)
                    }
                    
                    // 用户自定义技能
                    ForEach(filteredUserSkills) { skill in
                        skillCard(skill)
                    }
                }
                .padding()
            }
            
            // 执行结果
            if let result = executionResult {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("执行结果")
                            .font(.caption.bold())
                        Spacer()
                        Button { executionResult = nil } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                    }
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Filtered Skills
    
    private var categories: [String] {
        let cats = Set(BuiltInSkills.allBuiltIn.map(\.category))
        let userCats = Set(skills.map(\.category))
        return Array((cats.union(userCats))).sorted()
    }
    
    private var filteredSkills: [FileSkill] {
        let builtIn = BuiltInSkills.allBuiltIn
        return builtIn.filter { skill in
            (selectedCategory == "全部" || skill.category == selectedCategory) &&
            (searchText.isEmpty || skill.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private var filteredUserSkills: [FileSkill] {
        skills.filter { skill in
            (selectedCategory == "全部" || skill.category == selectedCategory) &&
            (searchText.isEmpty || skill.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    // MARK: - Components
    
    private func categoryChip(_ name: String) -> some View {
        Button {
            selectedCategory = name
        } label: {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    selectedCategory == name ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
    
    private func skillCard(_ skill: FileSkill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图标 + 名称
            HStack(spacing: 8) {
                Image(systemName: skill.icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.body.bold())
                        .lineLimit(1)
                    Text(skill.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 描述
            Text(skill.skillDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            Spacer()
            
            // 操作按钮
            HStack {
                Button("执行") {
                    executeSkill(skill)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isExecuting || !appState.llmIsConfigured)
                
                if !skill.isBuiltIn {
                    Button(role: .destructive) {
                        // 删除自定义技能
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
    
    // MARK: - Actions
    
    private func executeSkill(_ skill: FileSkill) {
        guard appState.llmIsConfigured else { return }
        
        isExecuting = true
        let files = appState.paneManager.activePane.files
        let directory = appState.paneManager.activePane.currentDirectory
        
        Task {
            do {
                let result = try await appState.skillEngine.execute(
                    skill: skill,
                    files: files,
                    in: directory,
                    llmConfig: appState.llmConfig
                )
                
                switch result {
                case .success(let message):
                    executionResult = message
                case .plan(let plan):
                    executionResult = plan.explanation + "\n" + plan.operations.map(\.displayText).joined(separator: "\n")
                case .failure(let error):
                    executionResult = "失败: \(error)"
                }
            } catch {
                executionResult = "错误: \(error.localizedDescription)"
            }
            isExecuting = false
        }
    }
    
    private func addSkill() {
        let skill = FileSkill(name: "新技能", description: "自定义技能描述", category: "自定义")
        modelContext.insert(skill)
    }
}
