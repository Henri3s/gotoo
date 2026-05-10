import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("llm_base_url") private var baseURL = "https://api.siliconflow.cn/v1"
    @AppStorage("llm_api_key") private var apiKey = ""
    @AppStorage("llm_model") private var model = "deepseek-ai/DeepSeek-V4-Flash"
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gear") }
            
            LLMPSettingsView(baseURL: $baseURL, apiKey: $apiKey, model: $model)
                .tabItem { Label("AI 模型", systemImage: "sparkles") }
        }
        .frame(width: 450, height: 300)
        .onChange(of: apiKey) { _, new in appState.llmAPIKey = new }
        .onChange(of: baseURL) { _, new in appState.llmBaseURL = new }
        .onChange(of: model) { _, new in appState.llmModel = new }
        .onAppear {
            appState.llmAPIKey = apiKey
            appState.llmBaseURL = baseURL
            appState.llmModel = model
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launch_at_login") private var launchAtLogin = false
    @AppStorage("show_hidden_files") private var showHidden = false
    
    var body: some View {
        Form {
            Toggle("登录时启动", isOn: $launchAtLogin)
            Toggle("显示隐藏文件", isOn: $showHidden)
        }
        .padding()
    }
}

struct LLMPSettingsView: View {
    @Binding var baseURL: String
    @Binding var apiKey: String
    @Binding var model: String
    
    var body: some View {
        Form {
            TextField("API Base URL", text: $baseURL)
            SecureField("API Key", text: $apiKey)
            TextField("模型名称", text: $model)
        }
        .padding()
    }
}
