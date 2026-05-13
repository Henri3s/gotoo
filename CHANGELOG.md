# Gotoo 版本记录

---

## v0.9 — 2026-05-13

### 全面代码审查与修复 (12 模块系统性诊断)

**P0 修复 (必须修)**

- **[安全] API Key 迁移到 Keychain** — 新增 `KeychainStore.swift`，API Key 从 UserDefaults 迁移到系统 Keychain，自动兼容旧版数据迁移
- **[致命] 菜单栏命令全部无效** — `GotooCommands` 改用 `@Environment(AppState.self)` 直接操作状态，删除 12 个无人监听的 `NotificationCenter` 定义
- **[并发] RuleMonitor Timer Sendable 违规** — 修复 Swift 6 strict concurrency 下 Timer 闭包捕获非 Sendable 类型的问题
- **[废弃] NSUserNotification → UNUserNotificationCenter** — 替换 macOS 11 已废弃的 API
- **[崩溃] ModelContainer fatalError → 优雅降级** — 创建失败时 fallback 到内存模式而非 crash
- **[性能] contentsRecursive 改 async** — 递归文件遍历不再阻塞主线程
- **[编译] ContentView 补 `import SwiftData`** — 消除隐式依赖

**P1 修复 (强烈建议)**

- **FileCategories / FileLabelColor 抽出独立文件** — 从 `FileRule.swift` 迁移到 `FileEngine.swift`，消除跨模块重复定义
- **移除 LLMSettings 多余 Schema 注册** — LLM 配置存在 AppState + Keychain，无需 SwiftData Model
- **aiMessages 添加 200 条上限** — 防止长时间使用内存持续增长
- **AppState 添加 `@unchecked Sendable`** — 解决 @Observable + @MainActor 的 Sendable 一致性
- **修复颜色字典重复 key** — "orange" 键冲突导致颜色映射错误
- **修复所有 16 个编译器警告 → 0 个警告**

### 构建状态

BUILD SUCCEEDED (macOS, arm64, Debug) — **0 warnings**

---

## v0.9 — 2026-05-13

### P2 优化批次

**性能优化**
- NSImage 图标缓存 — 列表滚动时不再反复调用 NSWorkspace.shared.icon
- ByteCountFormatter 静态缓存 — 避免每次创建格式化器实例
- DateFormatter 静态缓存 (SkillEngine)
- AIEngine 网络请求添加指数退避重试 (最多 2 次) + 请求取消机制

**安全加固**
- SettingsView API Key 改为通过 AppState → Keychain 存储，不再用 @AppStorage
- Shell Skill 执行前安全确认 — 用户可预览脚本内容后批准/拒绝
- 新增 PrivacyInfo.xcprivacy 隐私清单 (Apple 隐私合规)

**功能补全**
- OperationHistory undo 实现 — trash/tag/compress 撤销逻辑已补全
- App Intents 集成 — 支持 Spotlight 和快捷指令触发 (执行规则/AI面板/整理下载)
- 单元测试覆盖 — 20+ 测试用例覆盖 FileItem/FileCategories/AIActionPlan/PaneLayout/RuleTemplate/KeychainStore

**文档**
- 新增 README.md (项目介绍/安装/配置/快捷键/项目结构/技术栈)

### 构建状态

BUILD SUCCEEDED (macOS, arm64, Debug) — **0 warnings**

---

### UI 全面升级

- 工具栏增强：AI 面板切换按钮、技能库入口、规则管理、历史记录、撤销按钮
- AI 面板改为右侧叠加层（不再用 sheet 遮挡主界面）
- 规则编辑器全面增强：运行模式选择（自动/需确认/仅手动）、条件逻辑 AND/OR 切换、定时配置、条件取反支持
- 新增待确认操作面板：设置为「需确认」模式的规则匹配后，操作出现在面板中等待用户批准
- 快捷键系统：`Cmd+Shift+I` 切换 AI、`Cmd+Shift+R` 规则、`Cmd+Shift+K` 技能、`Cmd+Shift+H` 历史
- 侧边栏新增工具入口区域（规则、技能库、模板）
- 菜单栏增强：今日操作统计、模板库入口、技能库入口

### 构建状态

BUILD SUCCEEDED (macOS, arm64, Debug)

---

## v0.7 — 2026-05-12

### 高级 AI 集成

- 支持自定义系统提示词覆盖（通过文件夹配置注入）
- 技能提示词注入：`chatWithSkill()` 方法将技能描述和提示词打包发送给 LLM
- 对话历史上下文传递：多轮对话保持上下文连贯
- 增强 tool 定义：新增 `addTag`、`compress`、`notify` 三种操作类型
- 多模型快速配置：设置页新增 DeepSeek / OpenAI / Claude 预设按钮
- AI 面板快捷技能按钮行：一键触发内置技能
- 文件夹自定义提示词提示条：检测到当前文件夹有配置时显示提示

### 构建状态

BUILD SUCCEEDED

---

## v0.6 — 2026-05-12

### 批量操作增强 + 操作历史

- `OperationHistory` 操作历史记录系统，最多保留 1000 条
- 撤销栈（最多 50 层）：支持移动、复制、重命名、压缩操作的撤销
- 批量移动文件：`batchMove()` 方法，自动处理重名冲突（追加编号）
- 今日操作统计面板：显示总操作数、成功数、失败数
- 历史面板 UI：时间线视图，成功/失败状态标识，错误信息展示
- `FileEngine` 增强：文件移动/复制时自动处理目标已存在的情况

### 构建状态

BUILD SUCCEEDED

---

## v0.5 — 2026-05-12

### 规则模板市场

- 10 个预设规则模板：
  - 清理下载文件夹、图片分类、视频分类、旧文件清理
  - 截图整理、大文件提醒、代码文件整理
  - 自动压缩、PDF 文档归档、音频文件整理
- 按分类筛选模板（整理 / 维护 / 监控 / 开发 / 转换）
- 一键从模板创建 FileRule 并插入 SwiftData
- JSON 导入/导出模板支持
- `TemplateBrowserView`：网格卡片式浏览器界面

### 构建状态

BUILD SUCCEEDED

---

## v0.4 — 2026-05-12

### 文件夹级提示词系统

- `FolderConfig` SwiftData 模型：每个文件夹独立配置
- 自定义 AI 提示词：当在该文件夹触发 AI 操作时，覆盖默认系统提示词
- 自动执行提示词：文件夹有新文件时自动用指定提示词处理
- 关联技能列表：为文件夹绑定一组常用技能
- 自定义快捷操作 `QuickAction`：用户可为文件夹定义专属的快速文件操作
- 排除规则：按关键词排除不需要处理的文件
- 文件大小限制：跳过超过阈值的文件（默认 100MB）
- `FolderConfigView` 编辑器 UI：分组表单，支持路径选择、技能关联、快捷操作管理

### 构建状态

BUILD SUCCEEDED

---

## v0.3 — 2026-05-12

### Skill 技能系统

- `FileSkill` SwiftData 模型：支持三种类型（ai / shell / preset）
- 6 个内置技能：
  - 智能分类 — 按文件类型自动归类到子文件夹
  - 清理下载 — 清理安装包、临时文件和重复文件
  - 批量重命名 — 模板化重命名（日期、序号、正则）
  - 查找重复 — 按文件名或大小查找重复文件
  - 照片整理 — 按 EXIF 日期整理到年/月文件夹
  - 空间分析 — 分析磁盘占用，找出大文件
- `SkillEngine` 统一执行引擎：AI 技能调用 LLM，Shell 技能执行脚本
- AI 技能自动构建文件上下文并注入提示词
- Shell 技能支持变量替换（$FILE_PATH, $FILE_NAME, $FILE_DIR, $FILE_EXT）
- `SkillBrowserView` 技能浏览器：分类网格视图 + 搜索 + 一键执行

### 构建状态

BUILD SUCCEEDED

---

## v0.2 — 2026-05-12

### 增强规则引擎

**条件系统（30+ 种）：**
- 文件名：扩展名匹配、名称包含、名称正则、名称前缀、名称后缀、名称等于
- 大小：大于、小于、范围（支持人类可读格式：1KB, 5MB, 2GB）
- 时间：早于/晚于N天、今天修改/创建、本周修改/创建、本月修改/创建
- 类型：图片、视频、音频、文档、压缩包、代码文件、PDF（内置扩展名集合）
- 属性：隐藏文件、有标签、有颜色标记
- 内容：文件内容包含关键词（限制 10MB 以内，读取前 64KB）
- 条件取反：所有条件支持 `isNegated` 标志

**条件组合逻辑：**
- AND 模式（默认）：所有条件必须全部满足
- OR 模式：任一条件满足即匹配

**动作系统（15 种）：**
- 移动到、复制到、重命名（模板：{name}, {date}, {time}, {counter}等）、移到废纸篓
- 在 Finder 中显示、添加标签、移除标签、设置 Finder 颜色
- 移到日期子文件夹（可自定义日期格式）、运行 Shell 脚本、运行 AI 技能
- 压缩文件、发送通知、按类型归类、创建别名

**递归监控：**
- 支持递归子文件夹（可配置最大深度，默认 10 层）
- `contentsRecursive()` 方法

**运行模式：**
- 自动执行（auto）：匹配后立即执行
- 需确认（confirm）：匹配后加入待确认列表
- 仅手动（manual）：只在用户手动触发时执行

**定时执行：**
- `ScheduleConfig`：间隔（分钟）、时间窗口（开始/结束时间）、星期筛选
- 每分钟检查一次定时规则

**规则统计：**
- 运行次数计数、上次运行时间记录

### 构建状态

BUILD SUCCEEDED

---

## v0.1 — 初始版本（之前）

### 基础架构

- SwiftUI + SwiftData macOS 应用
- 多面板文件浏览器（单栏/双栏/三栏）
- 基础规则引擎：7 种条件 + 5 种动作
- 后台文件监控（DispatchSource vnode）
- AI 集成：OpenAI 兼容 API，tool calling，操作计划确认执行
- 菜单栏集成：监控开关、执行记录
- 设置页：LLM 配置

### 文件结构（初始）

```
gotoo/
  Core/RuleEngine/    — RuleEngine, FileRule, RuleMonitor
  Core/FileEngine/    — FileEngine
  Core/AIEngine/      — AIEngine, AIActionPlan, LLMSettings
  Core/Models/        — AppState, SidebarItem, PaneManager, AIMessage
  Features/Browser/   — PaneView, SidebarView, FilePreviewView
  Features/AI/        — AIPanelView
  Features/Rules/     — RulesView, MonitorLogView
  Features/Settings/  — SettingsView
```

---

## 项目规模变化

| 版本 | Swift 文件数 | 应用代码行数 | 新增模块 |
|------|-------------|-------------|---------|
| v0.1 | 18 | ~800 | 基础 |
| v0.2 | 18 | ~2400 | 条件/动作增强 |
| v0.3 | 20 | ~3200 | SkillEngine, FileSkill |
| v0.4 | 21 | ~3500 | FolderConfig |
| v0.5 | 22 | ~4150 | RuleTemplates |
| v0.6 | 23 | ~4600 | OperationHistory |
| v0.7 | 23 | ~5000 | AI 增强 |
| v0.8 | 31 | ~5222 | UI 全面升级 |
