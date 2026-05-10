import SwiftUI

struct AIPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var isLoading = false
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
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
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
            
            Divider()
            
            // Input
            HStack(spacing: 8) {
                TextField("输入指令，如：帮我整理下载文件夹...", text: $inputText)
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
    
    private func sendMessage() {
        guard !inputText.isEmpty, appState.llmIsConfigured else { return }
        let text = inputText
        inputText = ""
        
        appState.aiMessages.append(AIMessage(role: .user, content: text))
        isLoading = true
        
        // Build context
        var context = ""
        if let files = try? fileEngine.contents(of: appState.paneManager.activePane.currentDirectory) {
            context = files.map { f in
                "\(f.name) \(f.isDirectory ? "[文件夹]" : "\(f.formattedSize)")"
            }.joined(separator: "\n")
        }
        
        Task {
            do {
                let reply = try await aiEngine.send(
                    message: text,
                    context: context,
                    baseURL: appState.llmBaseURL,
                    apiKey: appState.llmAPIKey,
                    model: appState.llmModel
                )
                appState.aiMessages.append(AIMessage(role: .assistant, content: reply))
            } catch {
                appState.aiMessages.append(AIMessage(role: .error, content: "错误: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: AIMessage
    
    var bgColor: Color {
        switch message.role {
        case .user: return .accentColor.opacity(0.15)
        case .assistant: return .gray.opacity(0.1)
        case .system: return .blue.opacity(0.1)
        case .error: return .red.opacity(0.1)
        }
    }
    
    var body: some View {
        Text(message.content)
            .padding(10)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
