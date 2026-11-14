import XCTest
@testable import cellscopeCore

final class NeubauerTests: XCTestCase {
    func testPhysicalAreasAndSelection() {
        XCTAssertEqual(NeubauerGrid(mode: .overview).areaMM2, 9)
        XCTAssertEqual(NeubauerGrid(mode: .overview, selectedIndices: [0, 2, 6, 8]).areaMM2, 4)
        XCTAssertEqual(NeubauerGrid(mode: .singleLarge).areaMM2, 1)
        XCTAssertEqual(NeubauerGrid(mode: .redBloodCells).areaMM2 ?? 0, 0.2, accuracy: 1e-12)
        XCTAssertEqual(NeubauerGrid(mode: .redBloodCells, selectedIndices: Array(0..<25)).areaMM2, 1)
        XCTAssertNil(NeubauerGrid(mode: .custom).areaMM2)
        XCTAssertFalse(NeubauerGrid(mode: .overview, selectedIndices: []).isValid)
        XCTAssertFalse(NeubauerGrid(mode: .overview, selectedIndices: [9]).isValid)
        XCTAssertFalse(NeubauerGrid(mode: .overview, selectedIndices: [0, 0]).isValid)
    }
    func testFourCornerAverageUsesAllFourAndKeepsFractionalMean() throws {
        let inputs = CountInputs()
        let result = try XCTUnwrap(inputs.calculateFourCorners(counts: [40, 50, 60, 70]))
        XCTAssertEqual(result.concentration, 1_100_000, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.requiredMicroliters), 90.9090909, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(inputs.calculateFourCorners(counts: [1, 1, 1, 2])).concentration, 25_000, accuracy: 0.0001)
        XCTAssertNil(inputs.calculateFourCorners(counts: [40, 50, 60]))
        XCTAssertNil(inputs.calculateFourCorners(counts: [40, 50, 60, -1]))
        XCTAssertNil(inputs.calculateFourCorners(counts: [Int.max, 1, 1, 1]))
    }
    func testRBCFiveSquaresAndUnits() throws {
        var inputs = CountInputs(); inputs.area = NeubauerGrid(mode: .redBloodCells).areaText!
        inputs.dilution = "200"
        let result = try XCTUnwrap(inputs.calculate(count: 100))
        XCTAssertEqual(result.concentration, 1_000_000_000, accuracy: 0.1)
        XCTAssertEqual(result.concentration / 1000, 1_000_000, accuracy: 0.001)
    }
    func testTouchBoundaryRuleUsesExtentNotCenter() {
        let grid = NeubauerGrid(mode: .custom)
        let region = CountRegion(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        func marker(_ x: Double, _ y: Double, _ w: Double = 0.02, _ h: Double = 0.02) -> CellMarker {
            CellMarker(x: x + w / 2, y: y + h / 2, radius: 0.01, extent: CountRegion(x: x, y: y, width: w, height: h))
        }
        XCTAssertNotNil(grid.assignedIndex(for: marker(0.18, 0.4), in: region)) // touches left, center outside
        XCTAssertNotNil(grid.assignedIndex(for: marker(0.4, 0.18), in: region)) // touches top
        XCTAssertNil(grid.assignedIndex(for: marker(0.78, 0.4), in: region)) // touches right, center inside
        XCTAssertNil(grid.assignedIndex(for: marker(0.4, 0.78), in: region)) // touches bottom
        XCTAssertNil(grid.assignedIndex(for: marker(0.18, 0.78), in: region)) // exclusion takes precedence
        XCTAssertNil(grid.assignedIndex(for: marker(0.05, 0.05), in: region))
    }
    func testSharedBoundaryAssignedOnceAndRBCOutsideSquaresExcluded() {
        let region = CountRegion(x: 0, y: 0, width: 1, height: 1)
        let grid = NeubauerGrid(mode: .overview)
        let crossing = CellMarker(x: 1.0 / 3 - 0.005, y: 0.1, radius: 0.01,
            extent: CountRegion(x: 1.0 / 3 - 0.015, y: 0.09, width: 0.02, height: 0.02))
        XCTAssertEqual(grid.assignedIndex(for: crossing, in: region), 1)
        XCTAssertEqual(grid.counts([crossing], in: region).values.reduce(0, +), 1)
        let rbc = NeubauerGrid(mode: .redBloodCells)
        XCTAssertNotNil(rbc.assignedIndex(for: CellMarker(x: 0.1, y: 0.1, radius: 0.01), in: region))
        XCTAssertNil(rbc.assignedIndex(for: CellMarker(x: 0.3, y: 0.1, radius: 0.01), in: region))
    }
    func testTouchingCellsRemainOneClump() {
        let w = 200, h = 160
        var pixels = [UInt8](repeating: 225, count: w * h)
        for cx in [70, 82] {
            for y in 0..<h { for x in 0..<w where (x - cx) * (x - cx) + (y - 70) * (y - 70) <= 8 * 8 {
                pixels[y * w + x] = 60
            } }
        }
        var settings = DetectionSettings(); settings.minimumDiameter = 0.02; settings.maximumDiameter = 0.08
        let markers = CellDetector.detect(GrayImage(width: w, height: h, pixels: pixels),
            region: CountRegion(x: 0, y: 0, width: 1, height: 1), settings: settings)
        XCTAssertEqual(markers.count, 1)
    }
    func testOldMarkerWithoutBoundsStillDecodes() throws {
        let original = CellMarker(x: 0.5, y: 0.5, radius: 0.02)
        let data = try JSONEncoder().encode(original)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "extent")
        let restored = try JSONDecoder().decode(CellMarker.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.extent)
        XCTAssertEqual(restored.x, original.x)
    }
    func testAvailableCornerMeanAndTotalUseOnlyCountedArea() throws {
        var inputs = CountInputs(); inputs.suspensionVolume = "0.5"
        let single = try XCTUnwrap(inputs.calculateLargeSquares(counts:[40]))
        XCTAssertEqual(single.concentration,800_000,accuracy:1e-8)
        XCTAssertEqual(try XCTUnwrap(single.totalCells),400_000,accuracy:1e-8)
        let pair = try XCTUnwrap(inputs.calculateLargeSquares(counts:[40,60]))
        XCTAssertEqual(pair.concentration,1_000_000,accuracy:1e-8)
        XCTAssertEqual(try XCTUnwrap(pair.totalCells),500_000,accuracy:1e-8)
        XCTAssertEqual(try XCTUnwrap(pair.requiredMicroliters),100,accuracy:1e-8)
        let complete = try XCTUnwrap(inputs.calculateLargeSquares(counts:[40,50,60,70]))
        XCTAssertEqual(complete.concentration,try XCTUnwrap(inputs.calculateFourCorners(counts:[40,50,60,70])).concentration)
        XCTAssertNil(inputs.calculateLargeSquares(counts:[]))
        XCTAssertNil(inputs.calculateLargeSquares(counts:[-1]))
        XCTAssertNil(inputs.calculateLargeSquares(counts:[1,2,3,4,5]))
        XCTAssertNil(inputs.calculateLargeSquares(counts:[Int.max,1]))
    }
    func testChamberResetRestoresNumbersAndPreservesTargetAndSelectedArea() {
        for grid in [NeubauerGrid(mode:.custom),NeubauerGrid(mode:.redBloodCells),
                     NeubauerGrid(mode:.overview,selectedIndices:[0,2,6,8])] {
            var inputs = CountInputs()
            inputs.area = "99"; inputs.depth = "0.7"; inputs.dilution = "200"
            inputs.suspensionVolume = "0.05"; inputs.target = "250000"
            inputs.resetChamberParameters(for:grid)
            XCTAssertEqual(inputs.area,grid.areaText ?? "1")
            XCTAssertEqual(inputs.depth,"0.1")
            XCTAssertEqual(inputs.dilution,"2")
            XCTAssertEqual(inputs.suspensionVolume,"1")
            XCTAssertEqual(inputs.target,"250000")
        }
    }

}
