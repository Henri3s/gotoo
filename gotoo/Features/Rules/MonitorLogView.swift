import SwiftUI

struct MonitorLogView: View {
    let log: [RuleMonitor.ExecutionEntry]
    
    var body: some View {
        if log.isEmpty {
            ContentUnavailableView("暂无执行记录", systemImage: "clock", description: Text("规则执行后记录会出现在这里"))
        } else {
            Table(log.reversed()) {
                TableColumn("时间") { entry in
                    Text(entry.date.formatted(.dateTime.hour().minute().second()))
                        .font(.caption)
                }
                .width(70)
                TableColumn("规则") { entry in
                    Text(entry.ruleName).font(.caption)
                }
                .width(100)
                TableColumn("文件") { entry in
                    Text(entry.fileName).font(.caption).lineLimit(1)
                }
                TableColumn("动作") { entry in
                    Text(entry.action).font(.caption)
                }
                .width(80)
                TableColumn("结果") { entry in
                    HStack(spacing: 4) {
                        Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.success ? .green : .red)
                            .font(.caption)
                        if let err = entry.errorMessage {
                            Text(err).font(.caption2).foregroundStyle(.red).lineLimit(1)
                        }
                    }
                }
            }
            .tableStyle(.inset)
        }
    }
}
