import XCTest
@testable import cellscopeCore

final class cellscopeCoreTests: XCTestCase {
    func testStandardHemocytometerAndVolume() throws {
        let result = try XCTUnwrap(CountInputs().calculate(count: 50))
        XCTAssertEqual(result.concentration, 1_000_000, accuracy: 0.0001)
        XCTAssertEqual(result.totalCells, 1_000_000, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.requiredMicroliters), 100, accuracy: 0.0001)
        XCTAssertFalse(result.exceedsAvailable)
    }
    func testCustomAreaDepthAndDilution() throws {
        var inputs = CountInputs()
        inputs.area = "0.04"; inputs.depth = "0.2"; inputs.dilution = "20"
        inputs.suspensionVolume = "0.5"; inputs.target = "5000000"
        let result = try XCTUnwrap(inputs.calculate(count: 10))
        XCTAssertEqual(result.concentration, 25_000_000, accuracy: 0.001)
        XCTAssertEqual(result.totalCells, 12_500_000, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.requiredMicroliters), 200, accuracy: 0.001)
    }
    func testInvalidParametersAndZeroCount() throws {
        for invalid in ["0", "-2", "nan", "inf", "", "abc", "1e999"] {
            var inputs = CountInputs(); inputs.area = invalid
            XCTAssertNil(inputs.calculate(count: 30), invalid)
        }
        var inputs = CountInputs(); inputs.dilution = "0.5"
        XCTAssertNil(inputs.calculate(count: 30))
        inputs = CountInputs(); inputs.target = "1e308"; inputs.area = "1e308"
        XCTAssertNil(inputs.calculate(count: 10))
        let zero = try XCTUnwrap(CountInputs().calculate(count: 0))
        XCTAssertEqual(zero.concentration, 0)
        XCTAssertNil(zero.requiredMicroliters)
        XCTAssertNil(CountInputs().calculate(count: -1))
    }
    func testInsufficientSuspensionAndDecimalComma() throws {
        var inputs = CountInputs(); inputs.suspensionVolume = "0,01"
        let result = try XCTUnwrap(inputs.calculate(count: 50))
        XCTAssertTrue(result.exceedsAvailable)
        XCTAssertEqual(CountInputs.positiveNumber(" 0,1 "), 0.1)
    }
    func testBoundaryRule() {
        let region = CountRegion(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        XCTAssertTrue(region.contains(x: 0.1, y: 0.1))
        XCTAssertFalse(region.contains(x: 0.9, y: 0.5))
        XCTAssertFalse(region.contains(x: 0.5, y: 0.9))
    }
    func fixture(bright: Bool = false) -> GrayImage {
        let w = 200, h = 160
        var pixels = [UInt8](repeating: bright ? 25 : 225, count: w * h)
        // Three separated cells, one tiny contaminant, one long grid line.
        for (cx, cy, r) in [(40, 40, 5), (100, 80, 6), (160, 120, 5), (20, 130, 1)] {
            for y in 0..<h { for x in 0..<w where (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r {
                pixels[y * w + x] = bright ? 200 : 65
            } }
        }
        for x in 0..<w { pixels[15 * w + x] = bright ? 200 : 65 }
        return GrayImage(width: w, height: h, pixels: pixels)
    }
    func testDetectionRejectsGridAndDebrisAndHonorsROI() {
        var settings = DetectionSettings(); settings.minimumDiameter = 0.04; settings.maximumDiameter = 0.1
        let all = CellDetector.detect(fixture(), region: CountRegion(x: 0, y: 0, width: 1, height: 1), settings: settings)
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all.first?.x ?? 0, 0.2025, accuracy: 0.005)
        XCTAssertEqual(all.first?.y ?? 0, 0.253125, accuracy: 0.005)
        let roi = CellDetector.detect(fixture(), region: CountRegion(x: 0.4, y: 0.3, width: 0.5, height: 0.6), settings: settings)
        XCTAssertEqual(roi.count, 2)
    }
    func testBrightCellPolarityAndMalformedInput() {
        var settings = DetectionSettings(); settings.minimumDiameter = 0.04; settings.maximumDiameter = 0.1; settings.brightCells = true
        XCTAssertEqual(CellDetector.detect(fixture(bright: true), region: CountRegion(x: 0, y: 0, width: 1, height: 1), settings: settings).count, 3)
        XCTAssertTrue(CellDetector.detect(GrayImage(width: 20, height: 20, pixels: []), region: CountRegion(), settings: settings).isEmpty)
        XCTAssertTrue(CellDetector.detect(fixture(), region: CountRegion(width: -1), settings: settings).isEmpty)
        settings.sensitivity = .nan
        XCTAssertTrue(CellDetector.detect(fixture(), region: CountRegion(), settings: settings).isEmpty)
    }
}
