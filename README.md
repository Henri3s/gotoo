# Gotoo - macOS 智能文件管理器

<p align="center">
  <strong>Finder + Hazel + AI = Gotoo</strong><br>
  macOS 原生智能文件管理器，自动化规则引擎 + 大语言模型
</p>

## 特性

- **文件浏览** — Finder 风格侧边栏 + 文件列表 + 路径导航
- **自动化规则** — Hazel 风格条件匹配 + 自动动作（移动/复制/重命名/删除/标签）
- **AI 助手** — 集成 OpenAI 兼容 API，自然语言指令操作文件
- **文件监控** — DispatchSource vnode 实时监控文件夹变化
- **隐私优先** — API Key 本地存储，不上传任何数据
- **免费开源** — 无需 App Store，直接下载使用

## 系统要求

- macOS 14.0 (Sonoma) 或更高
- Apple Silicon / Intel

## 构建

```bash
git clone https://github.com/Henri3s/gotoo.git
cd gotoo
open gotoo.xcodeproj
# Xcode → Run (⌘R)
```

## AI 配置

打开 Gotoo → 设置 → AI 模型，填写：

| 字段 | 默认值 |
|------|--------|
| API Base URL | `https://api.siliconflow.cn/v1` |
| API Key | 你的 API Key |
| 模型 | `deepseek-ai/DeepSeek-V4-Flash` |

支持任何 OpenAI 兼容 API（SiliconFlow / DeepSeek / OpenAI / 本地 Ollama 等）。

## 自动化规则

1. 点击工具栏齿轮图标打开规则面板
2. 创建规则：选择监控文件夹 → 添加条件 → 添加动作
3. 条件类型：扩展名匹配、名称包含/正则、大小限制、时间限制
4. 动作类型：移动到、复制到、重命名、移到废纸篓

## 技术栈

- Swift 6 (strict concurrency)
- SwiftUI + SwiftData
- DispatchSource (vnode 文件监控)
- OpenAI 兼容 API (URLSession)
- 非 App Store 分发 (Developer ID + 公证)

## 项目结构

```
gotoo/
├── gotooApp.swift          # App 入口
├── ContentView.swift       # 主窗口
├── Core/
│   ├── FileEngine/         # 文件操作 + 监控
│   ├── RuleEngine/         # 规则匹配 + 执行
│   ├── AIEngine/           # LLM API 集成
│   └── Models/             # 数据模型
├── Features/
│   ├── Browser/            # 文件浏览 UI
│   ├── Rules/              # 规则管理 UI
│   ├── AI/                 # AI 面板 UI
│   └── Settings/           # 设置 UI
└── Shared/                 # 公共组件
```

## License

MIT
