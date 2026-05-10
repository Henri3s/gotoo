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
            // Header
            HStack {
                Image(systemName: "sparkles")
                Text("AI 助手")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding()
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        // 欢迎提示
                        if appState.aiMessages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("我可以帮你整理文件。试试说：")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                suggestionButton("帮我整理下载文件夹")
                                suggestionButton("把所有 PDF 移到文档文件夹")
                                suggestionButton("删除超过 30 天的旧文件")
                                suggestionButton("这个文件夹里有什么大文件？")
                            }
                            .padding()
                        }
                        
                        ForEach(appState.aiMessages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: appState.aiMessages.count) { _, _ in
                    if let last = appState.aiMessages.last {
                        withAnimation { proxy.scrollTo(last.id) }
                    }
                }
            }
            
            // Pending plan confirmation
            if let plan = pendingPlan {
                planConfirmation(plan)
            }
            
            // Execution results
            if let results = executionResults {
                resultsView(results)
            }
            
            Divider()
            
            // Input
            HStack(spacing: 8) {
                TextField("输入指令...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendMessage() }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .frame(minWidth: 300, minHeight: 400)
        .background(.background)
    }
    
    // MARK: - Suggestion Buttons
    
    private func suggestionButton(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            HStack {
                Image(systemName: "text.bubble")
                    .font(.caption)
                Text(text)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.tertiary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Plan Confirmation
    
    private func planConfirmation(_ plan: AIActionPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.checklist")
                Text("操作计划")
                    .font(.subheadline.bold())
                Spacer()
            }
            
            Text(plan.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(plan.operations) { op in
                HStack(spacing: 4) {
                    Image(systemName: actionIcon(op.action))
                        .font(.caption2)
                        .foregroundStyle(actionColor(op.action))
                    Text(op.displayText)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(.vertical, 1)
            }
            
            HStack {
                Button("执行") {
                    let results = aiEngine.execute(plan: plan, in: appState.paneManager.activePane.currentDirectory)
                    executionResults = results
                    pendingPlan = nil
                    appState.aiMessages.append(AIMessage(role: .assistant, content: "已执行 \(results.filter { $0.hasPrefix("OK") }.count) 个操作"))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("取消") {
                    pendingPlan = nil
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
    
    // MARK: - Results View
    
    private func resultsView(_ results: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("执行结果")
                .font(.caption.bold())
            ForEach(results, id: \.self) { result in
                HStack(spacing: 4) {
                    Image(systemName: result.hasPrefix("OK") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.hasPrefix("OK") ? .green : .red)
                        .font(.caption2)
                    Text(result).font(.caption2)
                }
            }
        }
        .padding(10)
        .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let apiKey = appState.llmAPIKey
        guard !apiKey.isEmpty else {
            appState.aiMessages.append(AIMessage(role: .error, content: "请先在设置中配置 API Key"))
            return
        }
        
        let text = inputText
        inputText = ""
        pendingPlan = nil
        executionResults = nil
        
        appState.aiMessages.append(AIMessage(role: .user, content: text))
        isLoading = true
        
        let dir = appState.paneManager.activePane.currentDirectory
        
        var context = ""
        if let files = try? fileEngine.contents(of: dir) {
            context = files.map { f in
                "\(f.name)\(f.isDirectory ? "/" : "") \(f.isDirectory ? "" : f.formattedSize)"
            }.joined(separator: "\n")
        }
        
        Task {
            do {
                let result = try await aiEngine.chat(
                    message: text,
                    context: context,
                    baseURL: appState.llmBaseURL,
                    apiKey: apiKey,
                    model: appState.llmModel
                )
                
                // Try to parse as action plan
                if let plan = aiEngine.parseActionPlan(from: result) {
                    pendingPlan = plan
                    appState.aiMessages.append(AIMessage(role: .assistant, content: plan.explanation))
                } else {
                    // Regular text response
                    appState.aiMessages.append(AIMessage(role: .assistant, content: result))
                }
            } catch {
                appState.aiMessages.append(AIMessage(role: .error, content: "错误: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }
    
    // MARK: - Helpers
    
    private func actionIcon(_ action: AIActionPlan.FileOperation.ActionKind) -> String {
        switch action {
        case .move: return "arrow.right"
        case .copy: return "doc.on.doc"
        case .rename: return "pencil"
        case .trash: return "trash"
        case .createFolder: return "folder.badge.plus"
        }
    }
    
    private func actionColor(_ action: AIActionPlan.FileOperation.ActionKind) -> Color {
        switch action {
        case .move: return .blue
        case .copy: return .cyan
        case .rename: return .orange
        case .trash: return .red
        case .createFolder: return .green
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage
    
    var bgColor: Color {
        switch message.role {
        case .user: return Color.accentColor.opacity(0.12)
        case .assistant: return Color.gray.opacity(0.08)
        case .system: return Color.blue.opacity(0.08)
        case .error: return Color.red.opacity(0.08)
        }
    }
    
    var icon: String {
        switch message.role {
        case .user: return "person"
        case .assistant: return "sparkles"
        case .system: return "info.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            Text(message.content)
                .font(.body)
                .textSelection(.enabled)
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 10))
    }
}
