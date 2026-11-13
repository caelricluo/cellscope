import SwiftUI

enum EditMode: String, CaseIterable, Identifiable {
    case inspect = "查看", region = "边框", add = "补标", remove = "删除"
    var id: String { rawValue }
    var icon: String {
        switch self { case .inspect: "viewfinder"; case .region: "crop"; case .add: "plus.circle"; case .remove: "minus.circle" }
    }
}

@MainActor final class CounterModel: ObservableObject {
    @Published var image: UIImage?
    @Published var markers: [CellMarker] = []
    @Published var showMarkerLabels = false
    @Published var region = CountRegion()
    @Published var alignment: GridQuad?
    @Published var gridDetection: GridDetection?
    @Published private var manualGridRequired = false
    @Published var gridStatus = ""
    @Published var isLocatingGrid = false
    @Published var estimatedDiameterPixels = 0.0
    @Published var grid = NeubauerGrid()
    @Published var activeField: FieldPosition = .topLeft
    @Published private var fields: [FieldPosition: CapturedField] = [:]
    @Published var settings = DetectionSettings() {
        didSet {
            guard oldValue != settings, !replacingSettings, image != nil, !isLocatingGrid else { return }
            if !parameterUndoCaptured { undoStack.append(markers); parameterUndoCaptured = true }
            scheduleDetection()
        }
    }
    @Published var activeHandle: GridHandle = .move
    @Published var nudgePixels = 1
    @Published var inputs = CountInputs()
    @Published var name = ""
    @Published var isDemo = false
    @Published var isDetecting = false
    @Published var mode: EditMode = .inspect
    @Published var records: [CountRecord] = []
    @Published var message: String?
    @Published var shareFiles: [URL] = []
    @Published var showShare = false
    @Published var hasAnalyzed = false
    private var undoStack: [[CellMarker]] = []
    private var revision = UUID()
    private var pendingDetection: Task<Void, Never>?
    private var runningDetection: Task<[CellDetectionReport], Never>?
    private var cachedGray: GrayImage?
    private var replacingSettings = false
    private var parameterUndoCaptured = false
    func beginParameterEditing() { parameterUndoCaptured = false }
    private func replaceSettings(_ value: DetectionSettings) {
        replacingSettings = true; settings = value; replacingSettings = false
    }
    private func invalidateDetection() {
        revision = UUID(); pendingDetection?.cancel(); runningDetection?.cancel()
        isDetecting = false; isLocatingGrid = false
    }
    private func grayImage() -> GrayImage? {
        if let cachedGray { return cachedGray }
        guard let image else { return nil }
        cachedGray = ImageService.grayscale(image)
        return cachedGray
    }
    var canUndo: Bool { !undoStack.isEmpty }
    var calculationInputs: CountInputs {
        var result = inputs
        if let area = grid.areaText { result.area = area }
        if grid.mode == .singleLarge { result.area = "4" }
        return result
    }
    var result: CountResult? {
        let ready = grid.mode == .singleLarge ? completedFields == 4 : hasAnalyzed
        guard ready, grid.isValid, !needsManualGrid else { return nil }
        if grid.mode == .singleLarge {
            return inputs.calculateFourCorners(counts: FieldPosition.allCases.map { field($0)?.state.markers.count ?? 0 })
        }
        return calculationInputs.calculate(count: totalCount)
    }
    var completedFields: Int { FieldPosition.allCases.filter { field($0).map { $0.state.hasAnalyzed && $0.state.requiresManualGrid != true } == true }.count }
    var capturedFields: Int { FieldPosition.allCases.filter { field($0) != nil }.count }
    var totalCount: Int {
        grid.mode == .singleLarge ? FieldPosition.allCases.reduce(0) { $0 + (field($1)?.state.markers.count ?? 0) } : markers.count
    }
    var meanCount: Double { Double(totalCount) / 4 }
    func field(_ position: FieldPosition) -> CapturedField? {
        if position == activeField, let image {
            return CapturedField(state: CountFieldRecord(position: position, region: region, markers: markers, settings: settings,
                areaConfirmed: false, reviewed: false, hasAnalyzed: hasAnalyzed, alignment: alignment, requiresManualGrid: manualGridRequired), image: image)
        }
        return fields[position]
    }
    func selectField(_ position: FieldPosition) {
        guard position != activeField, !isDetecting else { return }
        if let current = field(activeField) { fields[activeField] = current }
        activeField = position; undoStack = []; invalidateDetection(); cachedGray = nil
        if let snapshot = fields[position] {
            image = snapshot.image; region = snapshot.state.region; markers = snapshot.state.markers
            replaceSettings(snapshot.state.settings); hasAnalyzed = snapshot.state.hasAnalyzed
            alignment = snapshot.state.alignment; manualGridRequired = snapshot.state.requiresManualGrid ?? false
            estimatedDiameterPixels = ImageMath.median(markers.map { $0.radius * 2 * Double(min(snapshot.image.size.width, snapshot.image.size.height)) })
        } else {
            image = nil; region = CountRegion(); alignment = nil; manualGridRequired = false; estimatedDiameterPixels = 0; markers = []; replaceSettings(grid.mode.detectionSettings)
            hasAnalyzed = false
        }
        gridDetection = nil; gridStatus = manualGridRequired ? "点击「边框」调整计数区域" : (alignment == nil ? "" : "已恢复此图的自动边框")
        mode = .inspect
    }
    var squareCounts: [Int: Int] { grid.counts(markers, in: region, alignment: alignment) }
    var demoDescription: String {
        switch grid.mode {
        case .overview: "模拟图 · 9 大格各 9 个合成细胞，共 81 个"
        case .redBloodCells: "模拟图 · 25 中格各 4 个合成细胞，标准 5 中格共 20 个"
        default: "模拟图 · 内含 49 个合成细胞，仅供体验"
        }
    }

    init() {
        do { records = try RecordStore.load() }
        catch { message = "本地记录读取失败：\(error.localizedDescription)" }
    }
    func setImage(_ source: UIImage, demo: Bool = false) {
        invalidateDetection()
        if isDemo && !demo { fields = [:]; name = "" }
        fields.removeValue(forKey: activeField)
        image = ImageService.normalized(source)
        markers = []; undoStack = []; region = CountRegion(); alignment = nil; manualGridRequired = false; gridDetection = nil; gridStatus = ""; estimatedDiameterPixels = 0; hasAnalyzed = false
        cachedGray = nil; isDemo = demo; mode = .inspect
        if demo { name = grid.mode == .custom ? "模拟样本 · 49 个细胞" : "模拟样本 · \(grid.mode.title)" }
        inputs.area = grid.areaText ?? inputs.area; replaceSettings(grid.mode.detectionSettings)
        if !demo { if grid.mode == .custom { detect() } else { locateGrid() } }
    }
    func loadDemo() {
        fields = [:]; activeField = .topLeft
        setImage(ImageService.demo(mode: grid.mode), demo: true)
        mode = .inspect
        detect(populateDemoFields: grid.mode == .singleLarge)
    }
    func changeCountingMode(_ newMode: CountingMode) {
        guard newMode != grid.mode else { return }
        grid = NeubauerGrid(mode: newMode)
        fields = [:]; activeField = .topLeft
        replaceSettings(newMode.detectionSettings)
        inputs.area = grid.areaText ?? "1"; inputs.depth = "0.1"
        invalidateDetection(); markers = []; undoStack = []
        hasAnalyzed = false
        alignment = nil; manualGridRequired = false; gridDetection = nil; gridStatus = ""
        mode = .region
        if isDemo { loadDemo() }
        else if image != nil { if newMode == .custom { detect() } else { locateGrid() } }
    }
    func selectSquares(_ indices: [Int]) {
        let updated = NeubauerGrid(mode: grid.mode, selectedIndices: indices.sorted())
        guard updated.isValid, updated != grid else { return }
        grid = updated; inputs.area = grid.areaText ?? inputs.area
        invalidateDetection(); markers = []; undoStack = []
        hasAnalyzed = false
        scheduleDetection()
    }
    func toggleSquare(_ index: Int) {
        var selected = Set(grid.selectedIndices)
        if selected.contains(index) {
            guard selected.count > 1 else { message = "至少保留一个计数格。"; return }
            selected.remove(index)
        } else { selected.insert(index) }
        selectSquares(Array(selected))
    }
    var frameQuad: GridQuad { alignment ?? GridQuad(region: region) }
    func updateFrame(_ quad: GridQuad) {
        guard quad.isValid else { return }
        alignment = quad; region = quad.bounds; manualGridRequired = false
        gridStatus = "边框已调整"
        scheduleDetection()
    }
    func resetFrame() {
        updateFrame(gridDetection?.alignment(for: grid.mode) ?? GridQuad(region: CountRegion()))
    }
    func nudgeFrame(dx: Int, dy: Int) {
        guard let image else { return }
        updateFrame(frameQuad.adjusting(activeHandle,
            dx:Double(dx*nudgePixels)/Double(image.size.width),dy:Double(dy*nudgePixels)/Double(image.size.height)))
    }
    func locateGrid() {
        guard image != nil, let gray = grayImage() else { return }
        invalidateDetection()
        let token = UUID(); revision = token; isDetecting = true; isLocatingGrid = true
        manualGridRequired = grid.mode != .custom
        gridStatus = "正在定位网格…"
        let countingMode = grid.mode
        Task {
            let located = await Task.detached(priority: .userInitiated) { GridDetector.detect(gray) }.value
            guard revision == token else { return }
            gridDetection = located; gridStatus = located.summary
            isDetecting = false; isLocatingGrid = false
            if let quad = countingMode == .custom ? (located.central ?? located.corner ?? located.overview) : located.alignment(for: countingMode) {
                alignment = quad; manualGridRequired = false; region = quad.bounds; mode = .inspect
                detect()
            } else {
                alignment = nil; hasAnalyzed = false; markers = []; mode = .region
                if located.central != nil { gridStatus = "检测到中央网格，可切换红细胞模式" }
            }
        }
    }
    var needsManualGrid: Bool { manualGridRequired }
    func detect(populateDemoFields: Bool = false) {
        undoStack.append(markers)
        scheduleDetection(delay: 0, populateDemoFields: populateDemoFields)
    }
    /// Debounce rapid changes and publish only the newest image/field/parameter revision.
    private func scheduleDetection(delay: UInt64 = 180_000_000, populateDemoFields: Bool = false) {
        guard image != nil, !isLocatingGrid, !needsManualGrid else { return }
        pendingDetection?.cancel(); runningDetection?.cancel()
        let token = UUID(); revision = token; isDetecting = true
        pendingDetection = Task {
            do { try await Task.sleep(nanoseconds: delay) } catch { return }
            guard revision == token, !Task.isCancelled else { return }
            guard settings.automaticSize || settings.minimumDiameter <= settings.maximumDiameter else { isDetecting = false; return }
            guard let gray = grayImage(), let sourceImage = image else { isDetecting = false; return }
            let parameters = settings, roi = region, selection = grid, quad = alignment
            let work = Task.detached(priority: .userInitiated) {
                (0..<(populateDemoFields ? 4 : 1)).map { _ in
                    CellDetector.analyze(gray, region: roi, settings: parameters, grid: selection, alignment: quad)
                }
            }
            runningDetection = work
            let reports = await work.value
            guard revision == token, !Task.isCancelled else { return }
            markers = reports[0].markers; estimatedDiameterPixels = reports[0].estimatedDiameterPixels
            hasAnalyzed = true; isDetecting = false
            if populateDemoFields {
                for (index, position) in FieldPosition.allCases.enumerated() {
                    fields[position] = CapturedField(state: CountFieldRecord(position: position, region: roi,
                        markers: reports[index].markers, settings: parameters, areaConfirmed: false,
                        reviewed: false, hasAnalyzed: true), image: sourceImage)
                }
            }
        }
    }
    func tap(x: Double, y: Double) {
        guard !isDetecting, !needsManualGrid, let image else { return }
        switch mode {
        case .add:
            let r = settings.automaticSize && estimatedDiameterPixels > 0 ? estimatedDiameterPixels / Double(min(image.size.width, image.size.height)) / 2 : settings.minimumDiameter / 2
            let short = min(image.size.width, image.size.height)
            let rx = r * short / image.size.width, ry = r * short / image.size.height
            let candidate = CellMarker(x: x, y: y, radius: r, isManual: true,
                extent: CountRegion(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
            guard grid.assignedIndex(for: candidate, in: region, alignment: alignment) != nil else { return }
            undoStack.append(markers)
            markers.append(candidate)
            hasAnalyzed = true
        case .remove:
            let ratio = image.size.width / image.size.height
            let nearest = markers.enumerated().map { entry in
                (entry.offset, hypot((entry.element.x - x) * ratio, entry.element.y - y))
            }.min { $0.1 < $1.1 }
            if let nearest, nearest.1 < max(0.035, markers[nearest.0].radius * min(1, ratio) * 1.8) {
                undoStack.append(markers); markers.remove(at: nearest.0)
            }
        default: break
        }
    }
    func undo() {
        guard !isDetecting, let previous = undoStack.popLast() else { return }
        markers = previous
    }
    func save() {
        guard let image, result != nil, !isDetecting else {
            message = "正在更新计数或参数尚未完整。"; return
        }
        let captures = grid.mode == .singleLarge ? FieldPosition.allCases.compactMap { field($0) } : []
        let record = CountRecord(id: UUID(), date: Date(), name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "未命名样本" : name,
            isDemo: isDemo, region: region, markers: markers, inputs: calculationInputs, settings: settings,
            areaConfirmed: false, reviewed: false, grid: grid,
            fields: captures.isEmpty ? nil : captures.map(\.state), activeField: activeField, alignment: alignment)
        do {
            try RecordStore.save(record, image: image, records: records, fields: captures)
            records.insert(record, at: 0); message = "已保存到本机记录。"
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
    func restore(_ record: CountRecord) {
        guard let restoredImage = RecordStore.image(for: record) else { message = "记录图片无法读取。"; return }
        invalidateDetection(); image = restoredImage
        region = record.region; alignment = record.alignment; manualGridRequired = record.requiresManualGrid ?? false; gridDetection = nil; gridStatus = manualGridRequired ? "点击「边框」调整计数区域" : (alignment == nil ? "" : "已恢复此图的自动边框"); grid = record.grid ?? NeubauerGrid(mode: .custom)
        activeField = record.activeField ?? .topLeft
        fields = [:]
        for field in record.fields ?? [] {
            if let image = RecordStore.image(for: field, record: record) {
                fields[field.position] = CapturedField(state: field, image: image)
            }
        }
        markers = record.markers; inputs = record.inputs; replaceSettings(record.settings)
        estimatedDiameterPixels = ImageMath.median(markers.map { $0.radius * 2 * Double(min(restoredImage.size.width, restoredImage.size.height)) })
        if grid.mode == .singleLarge { inputs.area = "1" }
        name = record.name
        isDemo = record.isDemo; cachedGray = nil; hasAnalyzed = true; undoStack = []; mode = .inspect
    }
    func delete(_ record: CountRecord) {
        let remaining = records.filter { $0.id != record.id }
        do { try RecordStore.delete(record, remaining: remaining); records = remaining }
        catch { message = "删除失败：\(error.localizedDescription)" }
    }
    func export() {
        guard let image, let result, !isDetecting else { return }
        func csv(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let rows: [[String]] = [
            ["项目", "数值", "单位"], ["样本", name, ""], ["模拟数据", isDemo ? "是" : "否", ""],
            ["导出时间", ISO8601DateFormatter().string(from: Date()), ""],
            ["计数模式", grid.mode.title, ""],
            ["计数格", grid.mode == .singleLarge ? "A1;A3;C1;C3" : grid.selectedIndices.sorted().map { grid.label($0) }.joined(separator: ";"), ""],
            ["当前图边框定位", alignment == nil ? "矩形" : "四边形", ""],
            ["边界规则", "记上不记下，记左不记右", ""], ["团块规则", "每个相连团块计作一个对象", ""],
            ["细胞数", String(totalCount), "个"],
            ["区域面积", calculationInputs.area, "mm²"], ["腔室深度", inputs.depth, "mm"],
            ["稀释倍数", inputs.dilution, "×"], ["原液体积", inputs.suspensionVolume, "mL"],
            ["浓度", String(result.concentration), "cells/mL"], ["原液总细胞数", String(result.totalCells), "个"],
            ["目标细胞数", inputs.target, "个"], ["所需原液体积", result.requiredMicroliters.map { String($0) } ?? "无法计算", "µL"]
        ] + (grid.mode == .singleLarge
            ? FieldPosition.allCases.map { ["\($0.title) \($0.rawValue)", String(field($0)?.state.markers.count ?? 0), "个"] } + [["四角平均计数", String(meanCount), "个/大格"]]
            : grid.selectedIndices.sorted().map { ["分格计数 \(grid.label($0))", String(squareCounts[$0, default: 0]), "个"] })
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let report = folder.appendingPathComponent("CellScope.csv")
            let output = "\u{FEFF}" + rows.map { $0.map(csv).joined(separator: ",") }.joined(separator: "\r\n")
            try output.write(to: report, atomically: true, encoding: .utf8)
            var files = [report]
            if grid.mode == .singleLarge {
                for position in FieldPosition.allCases {
                    guard let field = field(position) else { continue }
                    let url = folder.appendingPathComponent("\(isDemo ? "模拟图-" : "")\(position.title)-\(position.rawValue).jpg")
                    let annotated = ImageService.annotated(field.image, markers: field.state.markers, region: field.state.region, grid: grid, alignment: field.state.alignment)
                    guard let data = annotated.jpegData(compressionQuality: 0.92) else { throw CocoaError(.fileWriteUnknown) }
                    try data.write(to: url, options: .atomic); files.append(url)
                }
            } else {
                let photo = folder.appendingPathComponent(isDemo ? "模拟图-标记.jpg" : "细胞标记.jpg")
                guard let data = ImageService.annotated(image, markers: markers, region: region, grid: grid, alignment: alignment).jpegData(compressionQuality: 0.92) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: photo, options: .atomic); files.append(photo)
            }
            shareFiles = files; showShare = true
        } catch { message = "导出失败：\(error.localizedDescription)" }
    }
}
