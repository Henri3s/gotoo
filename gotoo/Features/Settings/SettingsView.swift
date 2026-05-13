import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gear") }
            
            LLMPSettingsView()
                .tabItem { Label("AI 模型", systemImage: "sparkles") }
            
            AdvancedSettingsView()
                .tabItem { Label("高级", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 500, height: 380)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launch_at_login") private var launchAtLogin = false
    @AppStorage("show_hidden_files") private var showHidden = false
    @AppStorage("default_layout") private var defaultLayout = "双栏"
    @AppStorage("show_preview") private var showPreview = true
    @AppStorage("max_log_entries") private var maxLogEntries = 500
    
    var body: some View {
        Form {
            Section("启动") {
                Toggle("登录时启动", isOn: $launchAtLogin)
            }
            
            Section("浏览") {
                Toggle("显示隐藏文件", isOn: $showHidden)
                Toggle("显示文件预览", isOn: $showPreview)
                
                Picker("默认布局", selection: $defaultLayout) {
                    ForEach(PaneLayout.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            }
            
            Section("日志") {
                Picker("最大日志条数", selection: $maxLogEntries) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text("5000").tag(5000)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// AI 模型设置 — 通过 AppState 绑定，API Key 自动存入 Keychain
struct LLMPSettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("llm_temperature") private var temperature = 0.3
    @AppStorage("llm_max_tokens") private var maxTokens = 4096
    
    var body: some View {
        @Bindable var state = appState
        
        return Form {
            Section("API 配置") {
                TextField("API Base URL", text: $state.llmBaseURL)
                    .help("兼容 OpenAI API 格式的服务端地址")
                SecureField("API Key (Keychain 安全存储)", text: $state.llmAPIKey)
                    .help("API Key 通过 macOS Keychain 加密存储，不会明文保存")
                TextField("模型名称", text: $state.llmModel)
            }
            
            Section("参数") {
                HStack {
                    Text("温度")
                    Slider(value: $temperature, in: 0...1, step: 0.1)
                    Text(String(format: "%.1f", temperature))
                        .monospacedDigit()
                        .frame(width: 30)
                }
                
                Picker("最大 Token 数", selection: $maxTokens) {
                    Text("2048").tag(2048)
                    Text("4096").tag(4096)
                    Text("8192").tag(8192)
                    Text("16384").tag(16384)
                }
            }
            
            Section("快速配置") {
                HStack(spacing: 8) {
                    Button("DeepSeek") {
                        appState.llmBaseURL = "https://api.siliconflow.cn/v1"
                        appState.llmModel = "deepseek-ai/DeepSeek-V4-Flash"
                    }
                    Button("OpenAI") {
                        appState.llmBaseURL = "https://api.openai.com/v1"
                        appState.llmModel = "gpt-4o"
                    }
                    Button("Claude") {
                        appState.llmBaseURL = "https://api.anthropic.com/v1"
                        appState.llmModel = "claude-sonnet-4"
                    }
                }
                .controlSize(.small)
            }
            
            Section("安全说明") {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                    Text("API Key 通过 macOS Keychain 安全存储")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("monitor_debounce") private var debounceSeconds = 1.0
    @AppStorage("max_recursive_depth") private var maxRecursiveDepth = 10
    @AppStorage("confirm_destructive") private var confirmDestructive = true
    
    var body: some View {
        Form {
            Section("监控") {
                HStack {
                    Text("事件去抖（秒）")
                    Slider(value: $debounceSeconds, in: 0.5...5, step: 0.5)
                    Text(String(format: "%.1f", debounceSeconds))
                        .monospacedDigit()
                        .frame(width: 30)
                }
                Picker("递归最大深度", selection: $maxRecursiveDepth) {
                    ForEach(1...20, id: \.self) { Text("\($0)").tag($0) }
                }
            }
            
            Section("安全") {
                Toggle("破坏性操作需要确认", isOn: $confirmDestructive)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
