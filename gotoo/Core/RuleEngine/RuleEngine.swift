import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class RuleEngine {
    private let fileEngine = FileEngine()
    
    /// 对文件夹中的所有文件运行所有匹配的规则
    func apply(rules: [FileRule], toDirectory url: URL) throws -> [(FileRule, FileItem)] {
        let files = try fileEngine.contents(of: url)
        var matched: [(FileRule, FileItem)] = []
        for file in files where !file.isDirectory {
            for rule in rules where rule.matches(file: file) {
                matched.append((rule, file))
            }
        }
        return matched
    }
    
    /// 执行单条规则动作
    func execute(action: RuleAction, on file: FileItem) throws {
        let engine = fileEngine
        switch action.kind {
        case .moveTo:
            let dest = URL(fileURLWithPath: action.parameter)
            try engine.move(from: file.url, to: dest)
        case .copyTo:
            let dest = URL(fileURLWithPath: action.parameter)
            try engine.copy(from: file.url, to: dest)
        case .rename:
            _ = try engine.rename(file.url, to: action.parameter)
        case .trash:
            try engine.trash(file.url)
        case .reveal:
            NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
        }
    }
}
