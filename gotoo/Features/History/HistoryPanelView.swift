import SwiftUI

/// 操作历史面板
struct HistoryPanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("操作历史")
                    .font(.title2.bold())
                
                Spacer()
                
                // 今日统计
                let stats = appState.operationHistory.todayStats
                HStack(spacing: 12) {
                    Label("\(stats.total) 次操作", systemImage: "number")
                    Label("\(stats.success) 成功", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                    if stats.failed > 0 {
                        Label("\(stats.failed) 失败", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                
                Divider().frame(height: 16)
                
                if appState.operationHistory.canUndo {
                    Button("撤销上一步") {
                        _ = appState.operationHistory.undo()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("清空历史") {
                    appState.operationHistory.clearHistory()
                }
                .controlSize(.small)
            }
            .padding()
            
            Divider()
            
            // 历史列表
            let entries = appState.operationHistory.recent(100)
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("暂无操作记录", systemImage: "clock")
                } description: {
                    Text("执行文件操作后，记录会出现在这里")
                }
            } else {
                List {
                    ForEach(entries) { entry in
                        historyRow(entry)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    private func historyRow(_ entry: OperationHistory.HistoryEntry) -> some View {
        HStack(spacing: 10) {
            // 状态图标
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.success ? .green : .red)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.operation)
                    .font(.body)
                
                HStack(spacing: 4) {
                    Text(entry.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if let dest = entry.destination {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(dest)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if let error = entry.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 时间
            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
