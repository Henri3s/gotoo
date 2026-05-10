# Gotoo - macOS 智能文件管理器

<p align="center">
  <strong>Finder + Hazel + AI = Gotoo</strong><br>
  macOS 原生智能文件管理器，自动化规则引擎 + AI 助手
</p>

## 特性

### 文件浏览
- **多面板布局** — 单栏/双栏/三栏切换（QSpace 风格）
- **标签页系统** — 每个面板支持多标签，独立导航
- **拖放操作** — 从 Finder 拖入文件自动复制到当前面板
- **文件预览** — 图片/文本/PDF 内联预览
- **路径导航** — 面包屑地址栏，点击任意层级跳转
- **收藏夹** — 系统预设 + 自定义书签文件夹
- **状态栏** — 文件数量、选择数量、磁盘可用空间

### 自动化规则（Hazel 风格）
- **7 种条件** — 扩展名/名称/正则/大小/时间/标签
- **5 种动作** — 移动/复制/重命名/废纸篓/Finder 显示
- **后台监控** — DispatchSource 实时监听文件夹变化
- **自动执行** — 文件变更时自动匹配并执行规则
- **执行日志** — 带时间戳的操作记录，成功/失败状态
- **系统托盘** — 菜单栏快速启停监控、查看最近日志

### AI 助手
- **OpenAI 兼容** — 支持 SiliconFlow/DeepSeek/OpenAI/本地 Ollama
- **Function Calling** — AI 返回结构化文件操作计划
- **操作预览** — 执行前展示所有操作，用户确认后才执行
- **智能建议** — 一键触发常见整理任务
- **自然语言** — "帮我整理下载文件夹" 即可开始

### 快捷键
| 快捷键 | 功能 |
|--------|------|
| ⌘T | 新建标签页 |
| ⌘W | 关闭标签页 |
| ⌘U | 切换到下一个面板 |
| ⌘⇧1/2/3 | 切换单栏/双栏/三栏 |
| ⌘⇧S | 切换侧边栏 |
| ⌘⇧P | 切换预览面板 |
| ⌘⇧I | 打开 AI 面板 |
| ⌘⌥C | 拷贝文件路径 |
| ⌘⌥T | 在终端中打开 |
| ⌘⇧N | 新建文件夹 |

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

打开 Gotoo → 设置 → AI 模型：

| 字段 | 默认值 |
|------|--------|
| API Base URL | `https://api.siliconflow.cn/v1` |
| API Key | 你的 API Key |
| 模型 | `deepseek-ai/DeepSeek-V4-Flash` |

## 项目结构

```
gotoo/
├── gotooApp.swift              # App 入口 + MenuBarExtra
├── ContentView.swift           # 主窗口（多面板 + 侧边栏）
├── Core/
│   ├── Models/
│   │   ├── AppState.swift      # 全局状态
│   │   ├── PaneManager.swift   # 面板/标签管理
│   │   └── SidebarItem.swift   # 侧边栏数据模型
│   ├── FileEngine/             # 文件操作 + 监控
│   ├── RuleEngine/
│   │   ├── FileRule.swift      # 规则数据模型
│   │   ├── RuleEngine.swift    # 规则匹配引擎
│   │   └── RuleMonitor.swift   # 后台监控执行器
│   └── AIEngine/
│       ├── AIEngine.swift      # LLM API + Function Calling
│       ├── AIActionPlan.swift  # 操作计划数据模型
│       └── LLMSettings.swift   # SwiftData 持久化
├── Features/
│   ├── Browser/
│   │   ├── PaneView.swift      # 面板视图（标签+列表+预览）
│   │   ├── FilePreviewView.swift
│   │   └── FavoritesManagerView.swift
│   ├── Rules/
│   │   ├── RulesView.swift     # 规则管理 UI
│   │   └── MonitorLogView.swift
│   ├── AI/
│   │   └── AIPanelView.swift   # AI 对话面板
│   └── Settings/
│       └── SettingsView.swift
└── Shared/
    └── Components/
        └── GotooCommands.swift  # 菜单栏 + 快捷键
```

## 版本历史

- **v0.5** — 文件预览、侧边栏、收藏夹、增强右键菜单、快捷键
- **v0.4** — AI Function Calling 操作预览 + 用户确认
- **v0.3** — 后台规则监控、执行日志、系统托盘
- **v0.2** — 多面板布局、标签页、拖放、状态栏
- **v0.1** — 初始版本：文件浏览、规则引擎、AI 对话

## License

MIT
