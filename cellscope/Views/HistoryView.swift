import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var model: CounterModel
    let onRestore: () -> Void
    @State private var selected: CountRecord?
    @State private var deleting: CountRecord?
    var body: some View {
        NavigationStack {
            Group {
                if model.records.isEmpty {
                    ContentUnavailableView(tr("尚无样本记录"), systemImage: "tray", description: Text(tr("保存样本后，在这里回看图像与计算参数。")))
                } else {
                    List {
                        Section {
                            ForEach(model.records) { record in
                                Button { selected = record } label: {
                                    HStack(spacing: 14) {
                                        if let image = RecordStore.image(for: record) {
                                            Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(record.name).font(.headline).foregroundStyle(Palette.ink)
                                            Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Palette.muted)
                                            Text(summary(record) + (record.isDemo ? tr(" · 模拟数据") : ""))
                                                .font(.caption).foregroundStyle(Palette.green)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
                                    }.padding(.vertical, 5)
                                }.swipeActions { Button(role: .destructive) { deleting = record } label: { Label(tr("删除"), systemImage: "trash") } }
                            }
                        } footer: { Text(tr("记录与原始图像保存在本机，卸载应用会移除本地数据。可导出 CSV 和带标记图像进行备份。")) }
                    }.scrollContentBackground(.hidden)
                }
            }.background(Palette.paper).navigationTitle(tr("样本记录"))
                .confirmationDialog(tr("载入此记录？当前未保存的编辑将被替换。"), isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
                    Button(tr("载入样本")) { if let selected { model.restore(selected); onRestore() }; selected = nil }
                }
                .confirmationDialog(tr("删除此记录及其原始图像？"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button(tr("删除记录"), role: .destructive) { if let deleting { model.delete(deleting) }; deleting = nil }
                }
        }
    }
    private func summary(_ record: CountRecord) -> String {
        if let fields = record.fields, !fields.isEmpty {
            let sum = fields.reduce(0) { $0 + $1.markers.count }
            return trf("history.available_corners", fields.count, sum, formatted(Double(sum) / Double(fields.count)))
        }
        return trf("cell_count", record.markers.count)
    }
}
