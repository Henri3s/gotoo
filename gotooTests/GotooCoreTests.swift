import Testing
import Foundation
@testable import gotoo

// MARK: - FileItem Tests

@Test func fileItemExtensionLowercased() {
    let url = URL(fileURLWithPath: "/tmp/Test.JPG")
    let item = FileItem(
        url: url, name: "Test.JPG", isDirectory: false,
        size: 1024, modificationDate: nil, creationDate: nil
    )
    #expect(item.fileExtension == "jpg")
}

@Test func fileItemDirectoryCategory() {
    let url = URL(fileURLWithPath: "/tmp/Documents")
    let item = FileItem(
        url: url, name: "Documents", isDirectory: true,
        size: 0, modificationDate: nil, creationDate: nil
    )
    #expect(item.category == .folder)
}

@Test func fileItemImageCategory() {
    let url = URL(fileURLWithPath: "/tmp/photo.png")
    let item = FileItem(
        url: url, name: "photo.png", isDirectory: false,
        size: 2048, modificationDate: nil, creationDate: nil
    )
    #expect(item.category == .image)
}

@Test func fileItemVideoCategory() {
    let url = URL(fileURLWithPath: "/tmp/clip.mp4")
    let item = FileItem(
        url: url, name: "clip.mp4", isDirectory: false,
        size: 5000000, modificationDate: nil, creationDate: nil
    )
    #expect(item.category == .video)
}

@Test func fileItemDocumentCategory() {
    let url = URL(fileURLWithPath: "/tmp/report.pdf")
    let item = FileItem(
        url: url, name: "report.pdf", isDirectory: false,
        size: 3000, modificationDate: nil, creationDate: nil
    )
    #expect(item.category == .document)
}

@Test func fileItemCodeCategory() {
    let url = URL(fileURLWithPath: "/tmp/main.swift")
    let item = FileItem(
        url: url, name: "main.swift", isDirectory: false,
        size: 1500, modificationDate: nil, creationDate: nil
    )
    #expect(item.category == .code)
}

@Test func fileItemArchiveCategory() {
    let url = URL(fileURLWithPath: "/tmp/archive.zip")
    let item = FileItem(
        url: url, name: "archive.zip", isDirectory: false,
        size: 10000, modificationDate: nil, creationDate: nil
    )
    #expect(item.category == .archive)
}

@Test func fileItemFormattedSize() {
    let url = URL(fileURLWithPath: "/tmp/file.bin")
    let item = FileItem(
        url: url, name: "file.bin", isDirectory: false,
        size: 1048576, modificationDate: nil, creationDate: nil
    )
    #expect(item.formattedSize.contains("MB"))
}

// MARK: - FileCategories Tests

@Test func fileCategoriesImageContainsJPG() {
    #expect(FileCategories.imageExtensions.contains("jpg"))
    #expect(FileCategories.imageExtensions.contains("heic"))
    #expect(FileCategories.imageExtensions.contains("svg"))
}

@Test func fileCategoriesCodeContainsSwift() {
    #expect(FileCategories.codeExtensions.contains("swift"))
    #expect(FileCategories.codeExtensions.contains("py"))
    #expect(!FileCategories.codeExtensions.contains("exe"))
}

@Test func fileCategoriesArchiveContainsZip() {
    #expect(FileCategories.archiveExtensions.contains("zip"))
    #expect(FileCategories.archiveExtensions.contains("dmg"))
}

// MARK: - AIActionPlan Tests

@Test func actionPlanStats() {
    let plan = AIActionPlan(operations: [
        .init(source: "a.txt", action: .move, destination: "/dest"),
        .init(source: "b.txt", action: .copy, destination: "/dest"),
        .init(source: "c.txt", action: .trash),
        .init(source: "d.txt", action: .rename, destination: "new.txt"),
    ], explanation: "test")
    
    let stats = plan.stats
    #expect(stats.moves == 1)
    #expect(stats.copies == 1)
    #expect(stats.deletes == 1)
    #expect(stats.others == 1)
}

@Test func actionPlanDisplayText() {
    let op = AIActionPlan.FileOperation(source: "file.txt", action: .move, destination: "/new/path")
    #expect(op.displayText.contains("移动"))
    #expect(op.displayText.contains("file.txt"))
    #expect(op.displayText.contains("/new/path"))
}

@Test func actionPlanTrashDisplayText() {
    let op = AIActionPlan.FileOperation(source: "old.txt", action: .trash)
    #expect(op.displayText.contains("删除"))
    #expect(op.displayText.contains("old.txt"))
    #expect(op.displayText == "删除 old.txt")
}

// MARK: - PaneLayout Tests

@Test func paneLayoutCount() {
    #expect(PaneLayout.single.count == 1)
    #expect(PaneLayout.dual.count == 2)
    #expect(PaneLayout.triple.count == 3)
}

@Test func paneLayoutAllCases() {
    #expect(PaneLayout.allCases.count == 3)
}

// MARK: - FileCategory Tests

@Test func fileCategorySystemImage() {
    #expect(FileCategory.folder.systemImage == "folder")
    #expect(FileCategory.image.systemImage == "photo")
    #expect(FileCategory.video.systemImage == "film")
    #expect(FileCategory.archive.systemImage == "doc.zipper")
    #expect(FileCategory.code.systemImage == "chevron.left.forwardslash.chevron.right")
}

// MARK: - RuleTemplate Tests

@Test func ruleTemplateCategories() {
    let categories = RuleTemplates.categories
    #expect(categories.contains("整理"))
    #expect(categories.contains("监控"))
}

@Test func ruleTemplateAllCount() {
    #expect(RuleTemplates.all.count == 10)
}

@Test func ruleTemplateCreateRule() {
    let template = RuleTemplates.all[0]
    let rule = template.createRule(watchPath: "/tmp/Downloads")
    #expect(rule.name == template.name)
    #expect(rule.watchPath == "/tmp/Downloads")
    #expect(rule.conditions.count == template.conditions.count)
}

// MARK: - KeychainStore Tests (集成测试, 需要 Keychain 访问)

@Test func keychainStoreSaveAndLoad() {
    let testKey = "test_gotoo_key_\(UUID().uuidString)"
    let testValue = "test-api-key-12345"
    
    let saved = KeychainStore.save(key: testKey, value: testValue)
    #expect(saved)
    
    let loaded = KeychainStore.load(key: testKey)
    #expect(loaded == testValue)
    
    // 清理
    KeychainStore.delete(key: testKey)
    #expect(KeychainStore.load(key: testKey) == nil)
}

@Test func keychainStoreLoadNonexistent() {
    let result = KeychainStore.load(key: "nonexistent_key_\(UUID().uuidString)")
    #expect(result == nil)
}
