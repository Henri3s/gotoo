import SwiftUI

struct AIPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var pendingPlan: AIActionPlan?
    @State private var executionResults: [String]?
    
    private let aiEngine = AIEngine()
    private let fileEngine = FileEngine()
    
    var body: some View {
        VStack(spacing: 0) {
            // 对话消息
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if appState.aiMessages.isEmpty {
                            suggestions
                        }
                        ForEach(appState.aiMessages) { msg in
                            MessageBubble(message: msg).id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: appState.aiMessages.count) { _, _ in
                    if let last = appState.aiMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // 待确认的操作计划
            if let plan = pendingPlan {
                planCard(plan)
            }
            
            // 执行结果
            if let results = executionResults {
                resultsCard(results)
            }
            
            Divider()
            
            // 输入区
            HStack(spacing: 8) {
                TextField("描述你想要的文件操作...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendMessage() }
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: isLoading ? "hourglass" : "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty || isLoading)
                .buttonStyle(.borderless)
            }
            .padding(12)
        }
        .frame(minWidth: 300, minHeight: 400)
    }
    
    // MARK: - Suggestions
    
    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI 文件助手", systemImage: "sparkles")
                .font(.headline)
            Text("用自然语言描述你想要的文件操作，我会帮你整理。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                suggestionChip("整理下载文件夹中的文件")
                suggestionChip("把所有图片移到图片文件夹")
                suggestionChip("删除超过 30 天的旧文件")
                suggestionChip("这个文件夹里有什么大文件？")
            }
        }
        .padding()
    }
    
    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "text.bubble").font(.caption2)
                Text(text).font(.caption)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: Capsule())
    }
    
    // MARK: - Plan Card
    
    private func planCard(_ plan: AIActionPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("操作计划", systemImage: "list.bullet.clipboard")
                .font(.subheadline.bold())
            
            Text(plan.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            ForEach(plan.operations) { op in
                HStack(spacing: 6) {
                    Image(systemName: iconForAction(op.action))
                        .foregroundStyle(colorForAction(op.action))
                        .frame(width: 14)
                    Text(op.displayText)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            
            HStack {
                Button("确认执行") {
                    let results = aiEngine.execute(plan: plan, in: appState.paneManager.activePane.currentDirectory)
                    executionResults = results
                    pendingPlan = nil
                    let ok = results.filter { $0.hasPrefix("OK") }.count
                    appState.aiMessages.append(AIMessage(role: .assistant, content: "已执行 \(ok)/\(results.count) 个操作"))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("取消") { pendingPlan = nil }
                    .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.yellow.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Results Card
    
    private func resultsCard(_ results: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(results, id: \.self) { r in
                HStack(spacing: 4) {
                    Image(systemName: r.hasPrefix("OK") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(r.hasPrefix("OK") ? .green : .red)
                    Text(r).font(.caption)
                }
            }
        }
        .padding(10)
        .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let apiKey = appState.llmAPIKey
        guard !apiKey.isEmpty else {
            appState.aiMessages.append(AIMessage(role: .error, content: "请先在「设置 → AI 模型」中配置 API Key"))
            return
        }
        
        let text = inputText
        inputText = ""
        pendingPlan = nil
        executionResults = nil
        appState.aiMessages.append(AIMessage(role: .user, content: text))
        isLoading = true
        
        var context = ""
        if let files = try? fileEngine.contents(of: appState.paneManager.activePane.currentDirectory) {
            context = files.map { "\($0.name)\($0.isDirectory ? "/" : "") \($0.isDirectory ? "" : $0.formattedSize)" }.joined(separator: "\n")
        }
        
        Task {
            do {
                let result = try await aiEngine.chat(message: text, context: context, baseURL: appState.llmBaseURL, apiKey: apiKey, model: appState.llmModel)
                if let plan = aiEngine.parseActionPlan(from: result) {
                    pendingPlan = plan
                    appState.aiMessages.append(AIMessage(role: .assistant, content: plan.explanation))
                } else {
                    appState.aiMessages.append(AIMessage(role: .assistant, content: result))
                }
            } catch {
                appState.aiMessages.append(AIMessage(role: .error, content: error.localizedDescription))
            }
            isLoading = false
        }
    }
    
    private func iconForAction(_ a: AIActionPlan.FileOperation.ActionKind) -> String {
        switch a { case .move: "arrow.right"; case .copy: "doc.on.doc"; case .rename: "pencil"; case .trash: "trash"; case .createFolder: "folder.badge.plus" }
    }
    private func colorForAction(_ a: AIActionPlan.FileOperation.ActionKind) -> Color {
        switch a { case .move: .blue; case .copy: .cyan; case .rename: .orange; case .trash: .red; case .createFolder: .green }
    }
}

// MARK: - Message Bubble (HIG: clean, minimal)

struct MessageBubble: View {
    let message: AIMessage
    
    private var bg: Color {
        switch message.role {
        case .user: .accentColor.opacity(0.1)
        case .assistant: Color(nsColor: .controlBackgroundColor).opacity(0.5)
        case .system: .blue.opacity(0.08)
        case .error: .red.opacity(0.08)
        }
    }
    
    var body: some View {
        Text(message.content)
            .font(.body)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .background(bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
