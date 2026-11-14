import Foundation

/// Coordinates use the upright image's top-left origin, normalized to 0...1.
public struct CountRegion: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double = 0.1, y: Double = 0.1, width: Double = 0.8, height: Double = 0.8) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public func contains(x: Double, y: Double) -> Bool {
        // Consistent top/left inclusive, bottom/right exclusive center rule.
        x >= self.x && y >= self.y && x < self.x + width && y < self.y + height
    }
    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 &&
        width > 0 && height > 0 && x + width <= 1.000001 && y + height <= 1.000001
    }
}

public struct CellMarker: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var x: Double
    public var y: Double
    public var radius: Double // fraction of shorter image edge
    public var isManual: Bool
    public var extent: CountRegion? = nil
    public init(x: Double, y: Double, radius: Double, isManual: Bool = false, extent: CountRegion? = nil) {
        id = UUID(); self.x = x; self.y = y; self.radius = radius; self.isManual = isManual
        self.extent = extent
    }
}

public enum DetectionPolarity: String, CaseIterable, Sendable { case automatic, dark, bright }

public struct DetectionSettings: Codable, Equatable, Sendable {
    public var sensitivity: Double = 0.55
    public var minimumDiameter: Double = 0.012
    public var maximumDiameter: Double = 0.065
    public var brightCells: Bool = false
    public var automaticPolarity: Bool = true
    public var polarity: DetectionPolarity {
        get { automaticPolarity ? .automatic : (brightCells ? .bright : .dark) }
        set { automaticPolarity = newValue == .automatic; brightCells = newValue == .bright }
    }
    public var automaticSize: Bool = true
    public var isValid: Bool {
        sensitivity.isFinite && minimumDiameter.isFinite && maximumDiameter.isFinite &&
        (automaticSize || (minimumDiameter > 0 && maximumDiameter >= minimumDiameter && maximumDiameter <= 1))
    }
    public mutating func setMinimumDiameter(_ value: Double) {
        guard value.isFinite, value > 0, value <= 1 else { return }
        minimumDiameter = value
        maximumDiameter = max(maximumDiameter,value)
    }
    public mutating func setMaximumDiameter(_ value: Double) {
        guard value.isFinite, value > 0, value <= 1 else { return }
        maximumDiameter = value
        minimumDiameter = min(minimumDiameter,value)
    }
    public init() {}
    private enum CodingKeys: String, CodingKey { case sensitivity, minimumDiameter, maximumDiameter, brightCells, automaticSize, automaticPolarity }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sensitivity = try c.decodeIfPresent(Double.self, forKey: .sensitivity) ?? 0.55
        minimumDiameter = try c.decodeIfPresent(Double.self, forKey: .minimumDiameter) ?? 0.012
        maximumDiameter = try c.decodeIfPresent(Double.self, forKey: .maximumDiameter) ?? 0.065
        brightCells = try c.decodeIfPresent(Bool.self, forKey: .brightCells) ?? false
        automaticPolarity = try c.decodeIfPresent(Bool.self, forKey: .automaticPolarity) ?? false
        automaticSize = try c.decodeIfPresent(Bool.self, forKey: .automaticSize) ?? false
    }
}

public struct GrayImage: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]
    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width; self.height = height; self.pixels = pixels
    }
}

public struct CountInputs: Codable, Equatable, Sendable {
    public var area = "1"
    public var depth = "0.1"
    public var dilution = "2"
    public var suspensionVolume = "1"
    public var target = "100000"
    public init() {}

    public static func positiveNumber(_ text: String) -> Double? {
        let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "."))
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
    public func calculate(count: Int) -> CountResult? {
        guard count >= 0,
              let area = Self.positiveNumber(area), let depth = Self.positiveNumber(depth),
              let dilution = Self.positiveNumber(dilution), dilution >= 1 else { return nil }
        let sampledVolumeML = area * depth / 1000
        guard sampledVolumeML.isFinite, sampledVolumeML > 0 else { return nil }
        let concentration = Double(count) * dilution / sampledVolumeML
        guard concentration.isFinite else { return nil }
        let volume = Self.positiveNumber(suspensionVolume)
        let total = volume.flatMap { volume -> Double? in
            let value = concentration * volume
            return value.isFinite ? value : nil
        }
        let available = volume.flatMap { volume -> Double? in
            let value = volume * 1000
            return value.isFinite ? value : nil
        }
        let required = Self.positiveNumber(target).flatMap { target -> Double? in
            guard concentration > 0 else { return nil }
            let value = target / concentration * 1000
            return value.isFinite ? value : nil
        }
        return CountResult(concentration: concentration, totalCells: total,
                           requiredMicroliters: required, availableMicroliters: available)
    }
    public mutating func resetChamberParameters(for grid: NeubauerGrid) {
        let defaults = CountInputs()
        area = grid.areaText ?? defaults.area
        depth = defaults.depth
        dilution = defaults.dilution
        suspensionVolume = defaults.suspensionVolume
    }
    /// Mean across the available 1 mm² large squares; a complete set has four.
    public func calculateLargeSquares(counts: [Int]) -> CountResult? {
        guard (1...4).contains(counts.count), counts.allSatisfy({ $0 >= 0 }) else { return nil }
        var total = 0
        for count in counts {
            let next = total.addingReportingOverflow(count)
            guard !next.overflow else { return nil }
            total = next.partialValue
        }
        var inputs = self
        inputs.area = String(counts.count)
        return inputs.calculate(count: total)
    }
    public func calculateFourCorners(counts: [Int]) -> CountResult? {
        guard counts.count == 4 else { return nil }
        return calculateLargeSquares(counts: counts)
    }

}

public struct CountResult: Sendable {
    public let concentration: Double
    public let totalCells: Double?
    public let requiredMicroliters: Double?
    public let availableMicroliters: Double?
    public var exceedsAvailable: Bool {
        guard let requiredMicroliters, let availableMicroliters else { return false }
        return requiredMicroliters > availableMicroliters
    }
}
