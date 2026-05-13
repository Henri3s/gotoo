# Gotoo

macOS 智能文件管理器 — 规则驱动的自动化 + AI 文件指令

## 功能特性

### 🤖 AI 文件助手
- 用自然语言描述文件操作，AI 自动生成执行计划
- 支持 DeepSeek / OpenAI / Claude 等多种 LLM
- 文件夹级别自定义提示词

### ⚡ 规则引擎
- 30+ 条件类型（文件名/扩展名/大小/日期/类型匹配...）
- 15+ 动作类型（移动/复制/重命名/删除/压缩/标签/通知...）
- AND/OR 条件组合
- 自动/需确认/仅手动三种运行模式
- 定时执行（按周几/时间窗口/间隔）

### 🛠 技能系统
- 6 个内置技能（智能分类/清理下载/批量重命名/去重分析/照片整理/空间分析）
- 支持自定义 AI 技能和 Shell 脚本技能
- 技能可绑定到特定文件夹

### 📋 规则模板
- 10 个预设模板，一键创建规则
- 支持模板导入/导出 (JSON)

### 📂 多面板浏览
- 单栏/双栏/三栏布局切换
- 收藏夹快速导航
- 操作历史 + 撤销 (50 层)

## 系统要求

- macOS 15.0 (Sequoia) 或更高
- Apple Silicon / Intel

## 安装

### 从 GitHub Release 下载

1. 下载最新的 `Gotoo-x.x.x.dmg`
2. 打开 DMG，将 Gotoo.app 拖入「应用程序」文件夹
3. 首次打开时，右键点击 → 打开（绕过 Gatekeeper）

### 从源码构建

```bash
git clone https://github.com/Henri3s/gotoo.git
cd gotoo
xcodebuild -project gotoo.xcodeproj -scheme gotoo \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  build
```

或使用构建脚本：

```bash
./scripts/build-release.sh
# 产出: dist/Gotoo-x.x.x.dmg
```

## 配置

### AI 模型

打开 Gotoo → 设置 → AI 模型：

- 选择预设（DeepSeek / OpenAI / Claude）或自定义 API 地址
- 输入 API Key（通过 macOS Keychain 安全存储）
- 调整温度和最大 Token 数

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+Shift+I` | 切换 AI 面板 |
| `Cmd+Shift+R` | 打开规则管理 |
| `Cmd+Shift+K` | 打开技能库 |
| `Cmd+Shift+H` | 打开历史记录 |
| `Cmd+Shift+E` | 立即执行所有规则 |
| `Cmd+\` | 切换到下一个面板 |
| `Cmd+[` | 后退 |

## 项目结构

```
gotoo/
├── Core/
│   ├── AIEngine/          # LLM 集成、操作计划解析
│   ├── FileEngine/        # 文件操作、分类定义
│   ├── FolderConfig/      # 文件夹级配置
│   ├── History/           # 操作历史 + 撤销栈
│   ├── Models/            # AppState, PaneManager, FileItem
│   ├── RuleEngine/        # 规则匹配 + 执行引擎 + 监控
│   ├── RuleTemplates/     # 预设模板
│   ├── Security/          # Keychain 安全存储
│   └── SkillEngine/       # AI/Shell 技能执行
├── Features/
│   ├── AI/                # AI 对话面板
│   ├── Browser/           # 文件浏览 + 侧边栏
│   ├── FolderConfig/      # 文件夹配置编辑器
│   ├── History/           # 历史面板
│   ├── Rules/             # 规则编辑器
│   ├── Settings/          # 偏好设置
│   ├── Skills/            # 技能浏览器
│   └── Templates/         # 模板浏览器
└── Shared/Components/     # 菜单栏 + 快捷键
```

## 技术栈

- **SwiftUI** + **SwiftData** (macOS native)
- **Swift 6** strict concurrency
- **@Observable** macro
- **Keychain Services** (API Key 安全存储)
- **UserNotifications** (系统通知)
- **DispatchSource vnode** (文件系统监控)
- 无第三方依赖

## License

MIT
