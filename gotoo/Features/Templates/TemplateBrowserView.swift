import SwiftUI
import SwiftData

/// 规则模板浏览器 — 快速从预设模板创建规则
struct TemplateBrowserView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = "全部"
    @State private var selectedTemplate: RuleTemplate?
    
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("规则模板")
                    .font(.title2.bold())
                
                Text("从模板快速创建自动化规则")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("关闭") { dismiss() }
            }
            .padding()
            
            Divider()
            
            // 分类标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip("全部")
                    ForEach(RuleTemplates.categories, id: \.self) { cat in
                        categoryChip(cat)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // 模板网格
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredTemplates) { template in
                        templateCard(template)
                    }
                }
                .padding()
            }
        }
    }
    
    private var filteredTemplates: [RuleTemplate] {
        if selectedCategory == "全部" { return RuleTemplates.all }
        return RuleTemplates.templates(forCategory: selectedCategory)
    }
    
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
    
    private func templateCard(_ template: RuleTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 图标 + 名称
            HStack(spacing: 10) {
                Image(systemName: template.icon)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.body.bold())
                    Text(template.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 描述
            Text(template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            // 条件预览
            if !template.conditions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(template.conditions.indices, id: \.self) { i in
                        Text(template.conditions[i].kind.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.fill.tertiary, in: Capsule())
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack {
                Button("使用此模板") {
                    createFromTemplate(template)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                if let suggested = template.suggestedWatchPath {
                    let expanded = NSString(string: suggested).expandingTildeInPath
                    Text(expanded)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
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
    
    private func createFromTemplate(_ template: RuleTemplate) {
        let watchPath = template.suggestedWatchPath
            .map { NSString(string: $0).expandingTildeInPath }
            ?? appState.paneManager.activePane.currentDirectory.path
        
        let rule = template.createRule(watchPath: watchPath)
        modelContext.insert(rule)
        
        // 关闭模板面板，打开规则面板
        dismiss()
        appState.showRulesPanel = true
    }
}
