import SwiftUI

struct CountingModePanel: View {
    @ObservedObject var model: CounterModel
    @State private var pendingMode: CountingMode?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(tr("选择计数模式")).font(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Text("NEUBAUER IMPROVED").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
            }
            ForEach([CountingMode.overview, .singleLarge, .redBloodCells]) { mode in
                Button { choose(mode) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode == .overview ? "square.grid.3x3" : mode == .singleLarge ? "square.grid.2x2" : "drop.circle")
                            .font(.title3).frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.title).font(.subheadline.weight(.semibold))
                            Text(mode == .overview ? tr("全九格 / 四角大格 / 自选大格") : mode == .singleLarge ? tr("四角各拍一张，平均后计算") : tr("中央 25 中格 · 默认四角加中心 5 格"))
                                .font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 2)
                        Image(systemName: model.grid.mode == mode ? "checkmark.circle.fill" : "circle")
                    }.foregroundStyle(Palette.green).padding(12)
                        .background(model.grid.mode == mode ? Palette.green.opacity(0.08) : Palette.paper, in: RoundedRectangle(cornerRadius: 12))
                }.accessibilityIdentifier("countingMode-\(mode.rawValue)")
            }
            Button { choose(.custom) } label: {
                Label(model.grid.mode == .custom ? tr("当前：自定义区域") : tr("使用自定义面积"), systemImage: "ruler")
                    .font(.caption).foregroundStyle(Palette.muted)
            }.accessibilityIdentifier("countingMode-custom")
            Text(model.grid.mode.instruction).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.surface().disabled(model.isDetecting)
        .confirmationDialog(tr("切换计数模式并重新计数？"), isPresented: Binding(get: { pendingMode != nil }, set: { if !$0 { pendingMode = nil } }), titleVisibility: .visible) {
            Button(tr("切换模式")) { if let pendingMode { model.changeCountingMode(pendingMode) }; pendingMode = nil }
        }
    }
    private func choose(_ mode: CountingMode) {
        guard model.grid.mode != mode else { return }
        if !model.isDemo && (model.image != nil || model.capturedFields > 0) { pendingMode = mode }
        else { model.changeCountingMode(mode) }
    }
}

struct CornerFieldsPanel: View {
    @ObservedObject var model: CounterModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("10× 四角采集")).font(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Text(trf("fields.counted", model.completedFields)).font(.caption.monospacedDigit()).foregroundStyle(Palette.green).accessibilityIdentifier("countedFields")
            }
            HStack(spacing: 6) {
                ForEach(FieldPosition.allCases) { position in
                    let field = model.field(position)
                    Button { model.selectField(position) } label: {
                        VStack(spacing: 5) {
                            Text("\(position.title) \(position.rawValue)").font(.system(size: 10, weight: .medium))
                            Text(field.map { $0.state.hasAnalyzed ? "\($0.state.markers.count)" : tr("待计数") } ?? tr("待拍摄"))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text(field?.state.hasAnalyzed == true ? tr("已计数") : "").font(.system(size: 9))
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(model.activeField == position ? .white : Palette.green)
                            .background(model.activeField == position ? Palette.green : Palette.paper, in: RoundedRectangle(cornerRadius: 12))
                    }.accessibilityIdentifier("field-\(position.rawValue)")
                }
            }
            Text(trf("field.current", model.activeField.title))
                .font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            if model.completedFields > 0 {
                Text(trf("fields.current_mean", model.completedFields, model.totalCount, formatted(model.meanCount)))
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.green).accessibilityIdentifier("fourFieldMean")
            }
        }.surface().disabled(model.isDetecting)
    }
}

struct GridSquaresPanel: View {
    @ObservedObject var model: CounterModel
    var body: some View {
        let n = model.grid.mode.divisions
        let counts = model.squareCounts
        VStack(alignment: .leading, spacing: 10) {
            Text(model.grid.mode == .overview ? tr("选择计入统计的大格") : tr("选择红细胞计数中格"))
                .font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
            HStack(spacing: 12) {
                Button(model.grid.mode == .overview ? tr("四角大格") : tr("标准 5 中格")) {
                    model.selectSquares(model.grid.mode == .overview ? [0, 2, 6, 8] : [0, 4, 12, 20, 24])
                }.accessibilityIdentifier("selectStandardSquares")
                Button(model.grid.mode == .overview ? tr("全部 9 格") : tr("全部 25 中格")) { model.selectSquares(Array(0..<(n * n))) }
                    .accessibilityIdentifier("selectAllSquares")
            }.font(.caption)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: n), spacing: 5) {
                ForEach(0..<(n * n), id: \.self) { index in
                    let selected = model.grid.selectedIndices.contains(index)
                    Button { model.toggleSquare(index) } label: {
                        VStack(spacing: 3) {
                            Text(model.grid.label(index)).font(.system(size: 10, design: .monospaced))
                            Text(selected ? (model.hasAnalyzed ? "\(counts[index, default: 0])" : tr("计入")) : "—")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }.frame(maxWidth: .infinity).padding(.vertical, 8)
                            .foregroundStyle(selected ? .white : Palette.muted)
                            .background(selected ? Palette.green : Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                    }.accessibilityIdentifier("square-\(index)")
                }
            }
            Text(trf("grid.area", model.grid.selectedIndices.count, formatted(model.grid.mode.squareAreaMM2), model.grid.areaText ?? "—"))
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.green).accessibilityIdentifier("gridArea")
            Text(tr("高亮格计入统计，选择后自动更新。三线边界取中线。"))
                .font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.disabled(model.isDetecting)
    }
}
