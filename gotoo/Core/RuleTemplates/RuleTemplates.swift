import Foundation

/// 预设规则模板 — 用户可以从模板快速创建规则
struct RuleTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let conditions: [RuleCondition]
    let actions: [RuleAction]
    let suggestedWatchPath: String?  // 建议的监控路径（如 ~/Downloads）
    
    /// 从模板创建 FileRule
    func createRule(watchPath: String) -> FileRule {
        FileRule(
            name: name,
            watchPath: watchPath,
            conditions: conditions,
            actions: actions
        )
    }
}

// MARK: - Preset Templates

enum RuleTemplates {
    static let all: [RuleTemplate] = [
        // 下载文件夹整理
        .init(
            id: "clean-downloads",
            name: "清理下载文件夹",
            description: "自动清理下载文件夹中的安装包和旧文件",
            icon: "arrow.down.circle",
            category: "整理",
            conditions: [
                .init(kind: .isArchive, value: ""),
            ],
            actions: [
                .init(kind: .moveTo, parameter: "~/Downloads/安装包"),
            ],
            suggestedWatchPath: "~/Downloads"
        ),
        .init(
            id: "sort-images",
            name: "图片分类",
            description: "自动将图片文件移到图片文件夹",
            icon: "photo",
            category: "整理",
            conditions: [
                .init(kind: .isImage, value: ""),
            ],
            actions: [
                .init(kind: .moveTo, parameter: "~/Pictures/自动分类"),
            ],
            suggestedWatchPath: "~/Downloads"
        ),
        .init(
            id: "sort-videos",
            name: "视频分类",
            description: "自动将视频文件移到影片文件夹",
            icon: "film",
            category: "整理",
            conditions: [
                .init(kind: .isVideo, value: ""),
            ],
            actions: [
                .init(kind: .moveTo, parameter: "~/Movies/自动分类"),
            ],
            suggestedWatchPath: "~/Downloads"
        ),
        .init(
            id: "old-files-cleanup",
            name: "旧文件清理",
            description: "自动删除或归档超过指定天数的旧文件",
            icon: "clock",
            category: "维护",
            conditions: [
                .init(kind: .olderThanDays, value: "30"),
            ],
            actions: [
                .init(kind: .moveToDatedSubfolder, parameter: "yyyy-MM", parameter2: "~/Documents/归档"),
            ],
            suggestedWatchPath: "~/Downloads"
        ),
        .init(
            id: "screenshot-organizer",
            name: "截图整理",
            description: "自动将截图文件移到截图文件夹",
            icon: "camera",
            category: "整理",
            conditions: [
                .init(kind: .nameStartsWith, value: "截屏"),
                .init(kind: .extensionMatch, value: "png"),
            ],
            actions: [
                .init(kind: .moveToDatedSubfolder, parameter: "yyyy-MM", parameter2: "~/Pictures/截图"),
            ],
            suggestedWatchPath: "~/Desktop"
        ),
        .init(
            id: "large-file-alert",
            name: "大文件提醒",
            description: "检测超过 1GB 的大文件并发送通知",
            icon: "exclamationmark.triangle",
            category: "监控",
            conditions: [
                .init(kind: .sizeGreaterThan, value: "1GB"),
            ],
            actions: [
                .init(kind: .notify, parameter: "发现大文件: {name} ({size})"),
            ],
            suggestedWatchPath: "~/Documents"
        ),
        .init(
            id: "code-organizer",
            name: "代码文件整理",
            description: "自动将代码文件归类到项目文件夹",
            icon: "chevron.left.forwardslash.chevron.right",
            category: "开发",
            conditions: [
                .init(kind: .isCode, value: ""),
            ],
            actions: [
                .init(kind: .sortBy, parameter: "~/Documents/代码"),
            ],
            suggestedWatchPath: "~/Downloads"
        ),
        .init(
            id: "auto-compress",
            name: "自动压缩",
            description: "自动压缩指定类型的文件",
            icon: "doc.zipper",
            category: "转换",
            conditions: [
                .init(kind: .sizeGreaterThan, value: "50MB"),
                .init(kind: .olderThanDays, value: "7"),
            ],
            actions: [
                .init(kind: .compress),
            ],
            suggestedWatchPath: "~/Documents"
        ),
        .init(
            id: "pdf-organizer",
            name: "PDF 文档归档",
            description: "自动将PDF按月归档到文档文件夹",
            icon: "doc.richtext",
            category: "整理",
            conditions: [
                .init(kind: .isPDF, value: ""),
            ],
            actions: [
                .init(kind: .moveToDatedSubfolder, parameter: "yyyy-MM", parameter2: "~/Documents/PDF"),
            ],
            suggestedWatchPath: "~/Downloads"
        ),
        .init(
            id: "audio-organizer",
            name: "音频文件整理",
            description: "自动将音频文件移到音乐文件夹",
            icon: "music.note",
            category: "整理",
            conditions: [
                .init(kind: .isAudio, value: ""),
            ],
            actions: [
                .init(kind: .moveTo, parameter: "~/Music/自动导入"),
            ],
            suggestedWatchPath: "~/Downloads"
        ),
    ]
    
    /// 按分类获取模板
    static func templates(forCategory category: String) -> [RuleTemplate] {
        all.filter { $0.category == category }
    }
    
    /// 所有分类
    static var categories: [String] {
        Array(Set(all.map(\.category))).sorted()
    }
    
    /// 导出模板为 JSON
    static func exportTemplate(_ template: RuleTemplate) throws -> Data {
        try JSONEncoder().encode(template)
    }
    
    /// 从 JSON 导入模板
    static func importTemplate(from data: Data) throws -> RuleTemplate {
        try JSONDecoder().decode(RuleTemplate.self, from: data)
    }
}
