import Foundation
import SwiftData

/// 可复用的文件处理技能
@Model
final class FileSkill {
    var name: String
    var skillDescription: String
    var icon: String          // SF Symbol name
    var promptText: String    // AI 提示词（当 type == ai 时）
    var scriptText: String    // 脚本内容（当 type == shell 时）
    var type: String          // "ai" | "shell" | "preset"
    var inputData: Data?      // JSON encoded skill-specific config
    var isBuiltIn: Bool       // 内置技能不可删除
    var category: String      // 分类：整理、重命名、分析、转换
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, description: String, icon: String = "star", promptText: String = "", scriptText: String = "", type: String = "ai", isBuiltIn: Bool = false, category: String = "整理") {
        self.name = name
        self.skillDescription = description
        self.icon = icon
        self.promptText = promptText
        self.scriptText = scriptText
        self.type = type
        self.isBuiltIn = isBuiltIn
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 获取该技能用于 AI 上下文的描述
    var contextDescription: String {
        switch type {
        case "ai":
            return "[AI技能: \(name)] \(skillDescription)\n提示词: \(promptText)"
        case "shell":
            return "[脚本技能: \(name)] \(skillDescription)\n脚本: \(scriptText.prefix(200))"
        case "preset":
            return "[预设技能: \(name)] \(skillDescription)"
        default:
            return "[技能: \(name)] \(skillDescription)"
        }
    }
}

// MARK: - Built-in Skills

enum BuiltInSkills {
    /// 智能分类：按文件类型自动归类
    static let smartClassify = FileSkill(
        name: "智能分类",
        description: "自动按文件类型（图片、视频、文档、代码等）归类到对应子文件夹",
        icon: "square.grid.2x2",
        promptText: """
        请将当前目录中的文件按类型归类到以下子文件夹中：
        - 图片 (jpg, png, gif, heic, webp, svg 等)
        - 视频 (mp4, mov, avi, mkv 等)
        - 音频 (mp3, wav, flac, aac 等)
        - 文档 (pdf, doc, docx, xls, xlsx, ppt, pptx, txt, md 等)
        - 压缩包 (zip, rar, 7z, tar, gz, dmg 等)
        - 代码 (swift, py, js, ts, html, css, json 等)
        - 其他 (不属于以上分类的文件)
        
        请创建需要的子文件夹，然后将文件移动到对应的文件夹中。
        """,
        type: "ai",
        isBuiltIn: true,
        category: "整理"
    )
    
    /// 清理下载文件夹
    static let cleanDownloads = FileSkill(
        name: "清理下载",
        description: "清理下载文件夹中的安装包、临时文件和重复文件",
        icon: "trash.circle",
        promptText: """
        请帮我清理下载文件夹：
        1. 找出超过 30 天的旧文件，移到废纸篓
        2. 找出所有安装包 (.dmg, .pkg, .zip) 并移到 "安装包" 子文件夹
        3. 找出所有截图 (截图*.png, Screen Shot*.png) 并移到 "截图" 子文件夹
        4. 列出大文件 (>100MB) 供我决定是否保留
        """,
        type: "ai",
        isBuiltIn: true,
        category: "整理"
    )
    
    /// 批量重命名
    static let batchRename = FileSkill(
        name: "批量重命名",
        description: "使用模板批量重命名文件，支持日期、序号、正则替换",
        icon: "textformat.abc",
        promptText: """
        请帮我重命名选中的文件。用户会提供重命名规则：
        - {name}: 原始文件名
        - {date}: 当前日期 (yyyy-MM-dd)
        - {time}: 当前时间 (HH-mm-ss)
        - {counter}: 自动序号
        - {ext}: 扩展名
        - {parent}: 父文件夹名
        
        或者用户会描述重命名规则，请根据描述生成重命名计划。
        """,
        type: "ai",
        isBuiltIn: true,
        category: "重命名"
    )
    
    /// 去重分析
    static let findDuplicates = FileSkill(
        name: "查找重复",
        description: "查找当前目录中的重复文件（按文件名或大小）",
        icon: "doc.on.doc",
        promptText: """
        请分析当前目录，找出可能的重复文件：
        1. 完全同名的文件
        2. 文件名相似但扩展名不同的文件（如 photo.jpg 和 photo.png）
        3. 文件大小完全相同的文件（可能是复制品）
        
        请列出所有可疑的重复项，并建议保留哪个版本。
        """,
        type: "ai",
        isBuiltIn: true,
        category: "分析"
    )
    
    /// 照片整理
    static let photoOrganizer = FileSkill(
        name: "照片整理",
        description: "按拍摄日期（EXIF）将照片整理到年/月文件夹结构",
        icon: "photo.on.rectangle",
        promptText: """
        请帮我整理照片文件：
        1. 找出所有图片文件 (jpg, jpeg, png, heic, raw, cr2, nef)
        2. 按文件的修改日期（通常是拍摄日期）归类
        3. 创建 年份/月份 的文件夹结构 (如 2025/01-一月)
        4. 将照片移动到对应的日期文件夹中
        
        如果文件名包含日期信息（如 IMG_20250101_xxx.jpg），优先使用文件名中的日期。
        """,
        type: "ai",
        isBuiltIn: true,
        category: "整理"
    )
    
    /// 文件大小分析
    static let sizeAnalyzer = FileSkill(
        name: "空间分析",
        description: "分析目录空间占用，找出大文件和可清理内容",
        icon: "chart.pie",
        promptText: """
        请分析当前目录的磁盘空间占用：
        1. 列出最大的 20 个文件及其大小
        2. 按文件类型分类统计总大小
        3. 找出超过 1GB 的大文件
        4. 找出超过 90 天未访问的文件
        5. 给出空间优化建议
        """,
        type: "ai",
        isBuiltIn: true,
        category: "分析"
    )
    
    /// 获取所有内置技能
    static let allBuiltIn: [FileSkill] = [
        smartClassify, cleanDownloads, batchRename,
        findDuplicates, photoOrganizer, sizeAnalyzer
    ]
}
