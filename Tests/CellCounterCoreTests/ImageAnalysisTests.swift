import XCTest
@testable import CellCounterCore

final class ImageAnalysisTests: XCTestCase {
    private let whole = CountRegion(x:0,y:0,width:1,height:1)
    private func lattice(full: Bool = false, dark: Bool = false) -> GrayImage {
        let w = 900
        var p = [UInt8](repeating: dark ? 220 : 150,count:w*w)
        func line(_ a:Int,_ b:Int,_ c:Int,_ d:Int) {
            for y in b...d { for x in a...c { p[y*w+x] = dark ? 95 : 240 } }
        }
        let start = full ? 350 : 150, span = full ? 200 : 600
        for k in 0...20 {
            let q = start+k*span/20
            line(q,start,q,start+span); line(start,q,start+span,q)
        }
        if full { for k in 0...3 {
            let q = 150+k*200
            line(q,150,q,750); line(150,q,750,q)
        } }
        return GrayImage(width:w,height:w,pixels:p)
    }
    func testCentralLatticeCannotBecomeCroppedNineSquares() throws {
        for dark in [false,true] {
            let result = GridDetector.detect(lattice(dark:dark))
            let q = try XCTUnwrap(result.central)
            XCTAssertEqual(q.topLeft.x,1.0/6,accuracy:0.008)
            XCTAssertEqual(q.bottomRight.y,5.0/6,accuracy:0.008)
            XCTAssertNil(result.overview)
            XCTAssertNil(result.corner)
            XCTAssertNil(result.alignment(for:.singleLarge))
        }
    }
    func testFullNineRequiresObservedOuterRulings() throws {
        let result = GridDetector.detect(lattice(full:true))
        let q = try XCTUnwrap(result.overview)
        XCTAssertEqual(q.topLeft.x,1.0/6,accuracy:0.012)
        XCTAssertEqual(q.bottomRight.y,5.0/6,accuracy:0.012)
    }
    func testCornerLargeSquareAndTripleLineMiddle() throws {
        let w = 600
        var p = [UInt8](repeating:180,count:w*w)
        for k in 0...4 {
            for delta in [-4,0,4] {
                let q = 100+k*100+delta
                for a in 100...500 { p[a*w+q] = 235; p[q*w+a] = 235 }
            }
        }
        let result = GridDetector.detect(GrayImage(width:w,height:w,pixels:p))
        let q = try XCTUnwrap(result.corner)
        XCTAssertEqual(q.topLeft.x*Double(w),100,accuracy:2)
        XCTAssertEqual(q.bottomRight.y*Double(w),500,accuracy:2)
        XCTAssertNil(result.central)
    }
    func testCircleAndBlankAreNotCountingBorders() {
        let w = 300
        var p = [UInt8](repeating:10,count:w*w)
        for y in 0..<w { for x in 0..<w where pow(Double(x-150),2)+pow(Double(y-150),2)<140*140 { p[y*w+x] = 180 } }
        for image in [GrayImage(width:w,height:w,pixels:p),GrayImage(width:w,height:w,pixels:[UInt8](repeating:180,count:w*w))] {
            let r = GridDetector.detect(image)
            XCTAssertNil(r.central); XCTAssertNil(r.overview); XCTAssertNil(r.corner)
        }
    }
    func testSmallPhaseRingsClumpAndBrightGridIntersections() {
        let w = 400
        var p = [UInt8](repeating:180,count:w*w)
        for q in stride(from:40,through:360,by:40) { for a in 20..<380 { p[q*w+a] = 225; p[a*w+q] = 225 } }
        let centers = [(63,63,3),(102,103,4),(182,183,5),(263,262,4),(270,262,4)]
        for (cx,cy,r) in centers { for y in (cy-r)...(cy+r) { for x in (cx-r)...(cx+r) {
            let d = hypot(Double(x-cx),Double(y-cy))
            if d <= Double(r) { p[y*w+x] = d >= Double(r)-1.5 ? 70 : 235 }
        } } }
        let report = CellDetector.analyze(GrayImage(width:w,height:w,pixels:p),region:whole,settings:DetectionSettings())
        XCTAssertEqual(report.markers.count,4) // touching pair is one object
        for (x,y,_) in centers.prefix(3) {
            XCTAssertTrue(report.markers.contains { hypot($0.x*Double(w)-Double(x),$0.y*Double(w)-Double(y))<2 })
        }
        XCTAssertLessThan(report.estimatedDiameterPixels,15)
        XCTAssertTrue(report.markers.allSatisfy{$0.radius*Double(w)<12})
    }
    func testProjectiveMappingAndExtentBoundaryRules() throws {
        let q = GridQuad(topLeft:GridPoint(x:0.2,y:0.15),topRight:GridPoint(x:0.8,y:0.2),
            bottomRight:GridPoint(x:0.75,y:0.85),bottomLeft:GridPoint(x:0.15,y:0.75))
        XCTAssertTrue(q.isValid)
        for x in [0.0,0.3,1.0] { for y in [0.0,0.7,1.0] {
            let p = try XCTUnwrap(q.unproject(q.project(x:x,y:y)))
            XCTAssertEqual(p.x,x,accuracy:1e-10); XCTAssertEqual(p.y,y,accuracy:1e-10)
        } }
        let grid = NeubauerGrid(mode:.custom)
        let p = q.project(x:0.5,y:0.5)
        XCTAssertNotNil(grid.assignedIndex(for:CellMarker(x:p.x,y:p.y,radius:0.01),in:q.bounds,alignment:q))
        let outside = q.project(x:1.02,y:0.5)
        XCTAssertNil(grid.assignedIndex(for:CellMarker(x:outside.x,y:outside.y,radius:0.01),in:q.bounds,alignment:q))
        let a = GridQuad(region:CountRegion(x:0.2,y:0.2,width:0.6,height:0.6))
        let left = CellMarker(x:0.195,y:0.4,radius:0.01,extent:CountRegion(x:0.18,y:0.39,width:0.02,height:0.02))
        let right = CellMarker(x:0.79,y:0.4,radius:0.01,extent:CountRegion(x:0.78,y:0.39,width:0.02,height:0.02))
        XCTAssertNotNil(grid.assignedIndex(for:left,in:a.bounds,alignment:a))
        XCTAssertNil(grid.assignedIndex(for:right,in:a.bounds,alignment:a))
    }
    func testOldSettingsRetainManualSizeAndNewSettingsUseAutomaticSize() throws {
        let json = Data("{\"sensitivity\":0.55,\"minimumDiameter\":0.012,\"maximumDiameter\":0.065,\"brightCells\":false}".utf8)
        XCTAssertFalse(try JSONDecoder().decode(DetectionSettings.self,from:json).automaticSize)
        XCTAssertTrue(DetectionSettings().automaticSize)
    }
}
