# Gotoo v0.8.0 代码审查报告

**审查人**: 首席 macOS 架构师  
**日期**: 2026-05-13  
**代码规模**: 31 Swift 文件, 5222 行  
**编译器警告**: 16 个  

---

## 模块 1: 项目架构 & 依赖管理 — 需重点优化

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| Major | 所有 Core 层类被 View 层直接引用，无协议抽象 | AppState.swift 引用 RuleMonitor/SkillEngine/OperationHistory | 无法单元测试，耦合严重 | P1 |
| Major | FileCategories 枚举定义在 FileRule.swift 底部，但被 SidebarItem.swift 也引用 | FileRule.swift:296 | 跨模块依赖，应抽出独立文件 | P1 |
| Major | FileLabelColor 定义位置不当 | FileRule.swift:325 | 同上 | P1 |
| Minor | 无 Package.swift / SPM 本地包拆分 | 项目根目录 | 代码膨胀后难维护 | P2 |
| Minor | LLMSettings SwiftData Model 已注册但实际未使用（LLM 配置存在 AppState 内存中） | gotooApp.swift:9 vs AppState.swift | 多余的 Schema 注册浪费迁移成本 | P1 |

---

## 模块 2: 代码质量 & Swift 最佳实践 — 需重点优化

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| Critical | RuleMonitor Timer 闭包捕获非 Sendable 的 FileRule 数组 | RuleMonitor.swift:185-189 | Swift 6 并发安全违规，下一个 Xcode 版本将变成编译错误 | P0 |
| Major | AIEngine 在多个 View 中各自 `let aiEngine = AIEngine()` 创建新实例 | AIPanelView.swift:13, SkillEngine.swift:8 | 每次打开面板创建新引擎，URLSession/状态不复用 | P1 |
| Major | ContentView 缺少 `import SwiftData`，靠编译器隐式导入 | ContentView.swift:1 | 编译器警告，未来版本可能报错 | P0 |
| Major | 未使用的变量: `skillOverride`, `config`, `vals` | AIPanelView.swift:285,138; SidebarItem.swift:61 | 代码坏味道，隐藏潜在逻辑错误 | P1 |
| Minor | AIMessage 不是 @Observable 但被 ForEach 遍历 | AIMessage.swift | 若需动态更新消息内容会不刷新 | P2 |
| Minor | `try?` 静默吞掉错误 | FileEngine.swift 多处, RuleMonitor.swift:110 | 隐藏失败原因，难以调试 | P1 |

---

## 模块 3: 性能优化 — 良好

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| Major | FileItem.icon 每次访问都调用 NSWorkspace.shared.icon | SidebarItem.swift:50 | 列表滚动时反复生成 NSImage，CPU 峰值高 | P1 |
| Major | FileItem.struct 每次创建都调用 url.resourceValues | SidebarItem.swift:58-63 | labelColor/tags 属性每次访问都做 IO | P1 |
| Minor | contentsRecursive 同步递归遍历，大目录会阻塞主线程 | FileEngine.swift:51 | @MainActor 上执行，UI 卡死 | P0 |
| Minor | ByteCountFormatter 在 formattedSize 中每次创建实例 | SidebarItem.swift:53 | 应缓存 formatter | P2 |
| Minor | executionLog 用 Array.suffix 截断而非 CircularBuffer | RuleMonitor.swift:159-161 | 频繁数组重建 | P2 |

---

## 模块 4: 安全性 & 隐私合规 — 严重问题

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| **Critical** | API Key 明文存储在 `@AppStorage` (UserDefaults) | AppState.swift:19 | 任何进程可读取，严重安全隐患 | P0 |
| **Critical** | Shell Skill 执行无沙箱保护 | SkillEngine.swift:113-144 | 用户创建的 shell skill 可执行任意命令，脚本注入风险 | P0 |
| Major | 无 ATS 配置，LLM API 可能走 HTTP | SettingsView 默认 URL 是 HTTPS | 如果用户改为 HTTP URL，无保护 | P2 |
| Major | LLMSettings SwiftData 模型也明文存 API Key | LLMSettings.swift:7 | 双重暴露 | P1 |
| Minor | 缺少 PrivacyInfo.xcprivacy 隐私清单 | 项目根目录 | Apple 未来可能要求 | P2 |

---

## 模块 5: UI/UX & HIG — 良好

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| Major | Sheet 没有关闭手势/ESC 支持 | ContentView.swift:16-50 | macOS 用户期望 ESC 关闭 Sheet | P1 |
| Major | AI Panel 用 overlay 覆盖在内容区上 | ContentView.swift:152-160 | 遮挡文件列表内容，应改为侧边栏 | P1 |
| Minor | 硬编码中文字符串，无本地化 | 所有 View 文件 | 无法国际化 | P2 |
| Minor | 快捷键冲突: Cmd+R 刷新 vs Cmd+Shift+R 规则 | GotooCommands.swift | 可能与系统快捷键冲突 | P2 |

---

## 模块 6: 状态管理 & 数据流 — 需重点优化

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| **Critical** | AppState 是 @Observable 单例但 aiMessages 无大小限制 | AppState.swift:30 | 长时间使用内存持续增长 | P0 |
| Major | GotooCommands 用 NotificationCenter 发通知，但无人监听 | GotooCommands.swift 全文 | 所有菜单快捷键无效！ | P0 |
| Major | conversationHistory 存储在 AppState 内存中，无持久化 | AppState.swift:31 | App 重启后对话丢失 | P2 |
| Major | customFavorites 用内存元组数组，不持久化 | AppState.swift:33 | 重启后收藏夹丢失 | P1 |
| Minor | PaneState 不是 SwiftData 模型，面板状态不持久化 | PaneManager.swift | 可接受，但不保存布局偏好 | P2 |

---

## 模块 7: 网络与数据持久化 — 需重点优化

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| Major | AIEngine 无重试机制 | AIEngine.swift | 网络波动直接失败 | P1 |
| Major | 无请求取消机制 | AIEngine.swift | 用户切走面板后请求继续消耗资源 | P1 |
| Major | SwiftData ModelContainer 缺少迁移策略 | gotooApp.swift:8-16 | 模型变更后用户数据丢失 | P0 |
| Minor | URLSession 配置未设置缓存策略 | AIEngine.swift:8-12 | 重复请求浪费带宽 | P2 |
| Minor | JSON 解码全部用 try? 静默失败 | FileRule.swift, FolderConfig.swift | 数据损坏时无提示 | P1 |

---

## 模块 8: 崩溃 & 异常处理 — 需重点优化

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| **Critical** | fatalError 创建 ModelContainer | gotooApp.swift:14 | SwiftData 初始化失败直接崩溃，无优雅降级 | P0 |
| Major | FileEngine.move/copy 无原子性保证 | FileEngine.swift:114-141 | 操作中断可能留下部分移动的文件 | P1 |
| Major | OperationHistory.undo 的 trash/tag/compress 未实现 | OperationHistory.swift:119-125 | 撤销按钮点了没效果 | P1 |
| Minor | 缺少全局未捕获异常处理 | gotooApp.swift | 无 Crashlytics，线上崩溃无法追踪 | P2 |

---

## 模块 10: 测试覆盖 — 严重问题

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| **Critical** | 零测试覆盖 | 整个项目 | 重构时极易引入回归 | P0 |
| Major | 关键业务逻辑(RuleEngine.match, AIEngine.parseActionPlan)无测试 | RuleEngine.swift, AIEngine.swift | 核心功能无质量保证 | P0 |
| Minor | 无 UI 测试 | N/A | 关键用户流程无自动化验证 | P2 |

---

## 模块 11: 新特性适配 — 良好

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| Major | NSUserNotification 已废弃 | RuleEngine.swift:270-274 | 应改用 UNUserNotificationCenter | P0 |
| Minor | 缺少 App Intents (Spotlight/Shortcuts 集成) | N/A | 错失系统级发现入口 | P2 |
| Minor | 无 Widget 支持 | N/A | 错失通知中心展示机会 | P2 |

---

## 模块 12: AI 生成代码常见坑点 — 需重点优化

| 级别 | 问题 | 位置 | 风险 | 优先级 |
|------|------|------|------|--------|
| **Critical** | GotooCommands 定义了 Notification.Name 但从未 addObserver 监听 | GotooCommands.swift:129-143 | 所有菜单栏操作都是死代码 | P0 |
| Major | 幻觉 API: FileLabelColor.labelColor 属性实现为空 | SidebarItem.swift:60-65 | 代码存在但永远返回 .none | P1 |
| Major | 重复创建 DateFormatter 实例 | SkillEngine.swift:73, RuleEngine.swift:208 | 应使用静态缓存 | P1 |
| Major | RuleEngine 颜色字典有重复 key "orange" | RuleEngine.swift:178 | 后一个 orange 覆盖前一个 | P1 |
| Minor | 内置技能提示词硬编码中文 | FileSkill.swift | 无法本地化 | P2 |
| Minor | PaneContentView 的 `try?` 结果未使用 | PaneView.swift:155,161 | 潜在错误被吞 | P1 |

---

## 优先修复事项 (按紧急度排序)

### P0 — 必须在发布前修复 (不修就别上线)

1. **NotificationCenter 菜单命令全部无效** — 12 个 Notification.Name 定义了但没有任何 observe
2. **API Key 明文存储在 UserDefaults** — 迁移到 Keychain
3. **RuleMonitor Timer Sendable 违规** — Swift 6 编译错误预备
4. **NSUserNotification 废弃** — 替换为 UserNotifications
5. **ModelContainer fatalError** — 改为优雅降级
6. **contentsRecursive 阻塞主线程** — 改为 async
7. **ContentView 缺少 SwiftData import** — 编译器警告

### P1 — 强烈建议修复

8. AIEngine 多实例问题 — 改为 @State 单例
9. FileCategories/FileLabelColor 应抽出独立文件
10. LLMSettings 多余 Schema 注册
11. aiMessages 无上限 — 添加大小限制
12. customFavorites 不持久化 — 迁移到 SwiftData
13. Shell Skill 无沙箱 — 添加安全提示
14. Sheet 无 ESC 关闭

### P2 — 可后续优化

15. 本地化 (Localizable.strings)
16. 测试覆盖
17. 缓存优化 (DateFormatter, ByteCountFormatter, NSImage)
18. App Intents / Widget
19. 隐私清单文件
