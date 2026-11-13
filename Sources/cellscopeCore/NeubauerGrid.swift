import Foundation

public enum CountingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case overview, singleLarge, redBloodCells, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .overview: tr("4× · 完整九宫格")
        case .singleLarge: tr("10× · 单个大格")
        case .redBloodCells: tr("红细胞 · 中央计数区")
        case .custom: tr("自定义区域")
        }
    }
    public var instruction: String {
        switch self {
        case .overview: tr("框住完整 3 × 3 mm 九宫格；可统计全部九格或选择四角大格。")
        case .singleLarge: tr("分别拍摄四角的 1 × 1 mm 大格；四张图计数后取平均，再换算原液浓度。")
        case .redBloodCells: tr("框住中央完整 1 × 1 mm 大格；按 5 × 5 中格定位，默认统计四角与中心五个中格。")
        case .custom: tr("框住面积已知的矩形，手动填写实际计数面积。")
        }
    }
    public var divisions: Int {
        switch self { case .overview: 3; case .redBloodCells: 5; default: 1 }
    }
    public var squareAreaMM2: Double { self == .redBloodCells ? 0.04 : 1 }
    public var defaultIndices: [Int] {
        switch self { case .overview: Array(0..<9); case .redBloodCells: [0, 4, 12, 20, 24]; default: [0] }
    }
    public var detectionSettings: DetectionSettings {
        var settings = DetectionSettings()
        switch self {
        case .overview: settings.minimumDiameter = 0.006; settings.maximumDiameter = 0.035
        case .redBloodCells: settings.minimumDiameter = 0.006; settings.maximumDiameter = 0.035
        default: break
        }
        return settings
    }
}

/// The outer rectangle represents the whole physical reference grid, while
/// selectedIndices describes the disjoint squares that actually enter the count.
public struct NeubauerGrid: Codable, Equatable, Sendable {
    public var mode: CountingMode
    public var selectedIndices: [Int]
    public init(mode: CountingMode = .singleLarge, selectedIndices: [Int]? = nil) {
        self.mode = mode
        self.selectedIndices = selectedIndices ?? mode.defaultIndices
    }
    public var isValid: Bool {
        !selectedIndices.isEmpty && Set(selectedIndices).count == selectedIndices.count &&
        selectedIndices.allSatisfy { (0..<(mode.divisions * mode.divisions)).contains($0) }
    }
    public var areaMM2: Double? {
        guard mode != .custom, isValid else { return nil }
        return Double(selectedIndices.count) * mode.squareAreaMM2
    }
    public var areaText: String? { areaMM2.map { String(format: "%.6g", $0) } }
    public func square(_ index: Int, in region: CountRegion) -> CountRegion {
        let n = Double(mode.divisions)
        return CountRegion(x: region.x + Double(index % mode.divisions) * region.width / n,
                           y: region.y + Double(index / mode.divisions) * region.height / n,
                           width: region.width / n, height: region.height / n)
    }
    public func index(x: Double, y: Double, in region: CountRegion) -> Int? {
        guard region.isValid, region.contains(x: x, y: y) else { return nil }
        let n = mode.divisions
        let column = min(n - 1, Int(floor((x - region.x) / region.width * Double(n))))
        let row = min(n - 1, Int(floor((y - region.y) / region.height * Double(n))))
        return row * n + column
    }
    public func contains(x: Double, y: Double, in region: CountRegion) -> Bool {
        guard isValid, let index = index(x: x, y: y, in: region) else { return false }
        return selectedIndices.contains(index)
    }
    /// Touch rule: include objects touching top/left, exclude any touching
    /// bottom/right. Test object extent rather than only its center.
    public func assignedIndex(for marker: CellMarker, in region: CountRegion, alignment: GridQuad? = nil) -> Int? {
        if let alignment {
            guard let transformed = alignment.markerInUnitSquare(marker) else { return nil }
            return assignedIndex(for: transformed, in: CountRegion(x: 0, y: 0, width: 1, height: 1))
        }
        guard isValid else { return nil }
        guard let extent = marker.extent else {
            guard let index = index(x: marker.x, y: marker.y, in: region), selectedIndices.contains(index) else { return nil }
            return index // Historical markers did not store object bounds.
        }
        guard [extent.x, extent.y, extent.width, extent.height].allSatisfy(\.isFinite),
              extent.width >= 0, extent.height >= 0 else { return nil }
        let right = extent.x + extent.width, bottom = extent.y + extent.height
        let epsilon = 1e-10
        return selectedIndices.sorted().first { index in
            let square = square(index, in: region)
            return right >= square.x - epsilon && bottom >= square.y - epsilon &&
                extent.x < square.x + square.width && extent.y < square.y + square.height &&
                right < square.x + square.width - epsilon && bottom < square.y + square.height - epsilon
        }
    }
    public func label(_ index: Int) -> String {
        if mode == .overview { return "\(["A", "B", "C"][index / 3])\(index % 3 + 1)" }
        return String(index + 1)
    }
    public func counts(_ markers: [CellMarker], in region: CountRegion, alignment: GridQuad? = nil) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for marker in markers {
            if let index = assignedIndex(for: marker, in: region, alignment: alignment) {
                counts[index, default: 0] += 1
            }
        }
        return counts
    }
}

public enum FieldPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case topLeft = "A1", topRight = "A3", bottomLeft = "C1", bottomRight = "C3"
    public var id: String { rawValue }
    public var title: String {
        switch self { case .topLeft: tr("左上"); case .topRight: tr("右上"); case .bottomLeft: tr("左下"); case .bottomRight: tr("右下") }
    }
}
