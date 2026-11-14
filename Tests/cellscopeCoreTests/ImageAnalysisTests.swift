import XCTest
@testable import cellscopeCore

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
        // Automatic polarity measures the combined bright/dark halo support.
        XCTAssertLessThanOrEqual(report.estimatedDiameterPixels,16)
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
    func testFrameTranslationClampsWithoutChangingShape() {
        let q = GridQuad(region:CountRegion(x:0.2,y:0.3,width:0.5,height:0.4))
        let shifted = q.adjusting(.move,dx:0.9,dy:-1)
        XCTAssertEqual(shifted.bounds.x,0.5,accuracy:1e-12)
        XCTAssertEqual(shifted.bounds.y,0,accuracy:1e-12)
        XCTAssertEqual(shifted.bounds.width,0.5,accuracy:1e-12)
        XCTAssertEqual(shifted.bounds.height,0.4,accuracy:1e-12)
        XCTAssertTrue(shifted.isValid)
    }
    func testFrameCornersAndEdgesKeepPerspectiveAndRejectCrossing() {
        let q = GridQuad(region:CountRegion(x:0.2,y:0.2,width:0.6,height:0.6))
        let moved = q.adjusting(.topLeft,dx:0.03,dy:0.04)
        XCTAssertEqual(moved.topLeft.x,0.23,accuracy:1e-12)
        XCTAssertEqual(moved.topRight,q.topRight)
        XCTAssertEqual(moved.bottomLeft,q.bottomLeft)
        let edge = moved.adjusting(.right,dx:-0.02,dy:0)
        XCTAssertEqual(edge.topRight.x,0.78,accuracy:1e-12)
        XCTAssertEqual(edge.bottomRight.x,0.78,accuracy:1e-12)
        XCTAssertEqual(q.adjusting(.topLeft,dx:0.7,dy:0.7),q)
        XCTAssertEqual(q.adjusting(.move,dx:.nan,dy:0),q)
    }
    func testAutomaticSizeIgnoresUnusedManualRange() {
        var s = DetectionSettings(); s.minimumDiameter = 0.08; s.maximumDiameter = 0.04
        let fixture = cellscopeCoreTests().fixture()
        XCTAssertEqual(CellDetector.detect(fixture,region:whole,settings:s).count,3)
        s.automaticSize = false
        XCTAssertTrue(CellDetector.detect(fixture,region:whole,settings:s).isEmpty)
    }

    func testFaintMixedPolarityCellsRespondAtMaximumSensitivity() {
        let w = 420, h = 400
        var p = [UInt8](repeating:180,count:w*h)
        for y in 0..<h { for x in 0..<w {
            // Smooth illumination and deterministic sensor noise, independent of targets.
            p[y*w+x] = UInt8(165+x/35+y/50+((x*17+y*13)%3)-1)
        } }
        let centers = [(83,90,1.0,18.0),(185,110,-1.0,18.0),(305,95,1.0,18.0),(115,260,-1.0,18.0),(305,280,1.0,6.5)]
        for (cx,cy,sign,spread) in centers { for y in (cy-10)...(cy+10) { for x in (cx-10)...(cx+10) {
            let r2 = Double((x-cx)*(x-cx)+(y-cy)*(y-cy))
            p[y*w+x] = UInt8(clamping:Int(Double(p[y*w+x])+sign*11*exp(-r2/spread)))
        } } }
        let image = GrayImage(width:w,height:h,pixels:p)
        var settings = DetectionSettings();settings.sensitivity = 1
        let result = CellDetector.detect(image,region:whole,settings:settings)
        XCTAssertEqual(result.count,centers.count)
        for (x,y,_,_) in centers {
            XCTAssertTrue(result.contains{hypot($0.x*Double(w)-Double(x),$0.y*Double(h)-Double(y))<3})
        }
        settings.sensitivity = 0
        XCTAssertTrue(CellDetector.detect(image,region:whole,settings:settings).isEmpty)
        settings.sensitivity = 1;settings.polarity = .bright
        XCTAssertEqual(CellDetector.detect(image,region:whole,settings:settings).count,3)
        settings.polarity = .dark
        XCTAssertEqual(CellDetector.detect(image,region:whole,settings:settings).count,2)
    }
    func testMaximumSensitivityDoesNotTurnFlatNoiseOrRulingsIntoCells() {
        let w = 400
        var p = [UInt8](repeating:180,count:w*w)
        for y in 0..<w { for x in 0..<w { p[y*w+x] = UInt8(170+x/40+((x*17+y*13)%3)-1) } }
        for q in stride(from:40,through:360,by:80) { for a in 10..<390 {
            p[q*w+a] = 205; p[a*w+q] = 135
        } }
        var settings = DetectionSettings();settings.sensitivity = 1
        XCTAssertTrue(CellDetector.detect(GrayImage(width:w,height:w,pixels:p),region:whole,settings:settings).isEmpty)
    }
    func testPolaritySettingsRoundTripAndLegacyChoice() throws {
        var settings = DetectionSettings()
        XCTAssertEqual(settings.polarity,.automatic)
        for polarity in DetectionPolarity.allCases {
            settings.polarity = polarity
            let decoded = try JSONDecoder().decode(DetectionSettings.self,from:JSONEncoder().encode(settings))
            XCTAssertEqual(decoded,settings);XCTAssertEqual(decoded.polarity,polarity)
        }
        let old = Data("{\"brightCells\":true,\"automaticSize\":true}".utf8)
        XCTAssertEqual(try JSONDecoder().decode(DetectionSettings.self,from:old).polarity,.bright)
    }
    func testTiltedCornerBesideDenseCentralBands() throws {
        let w = 900, h = 960
        var p = [UInt8](repeating:180,count:w*h)
        let verticals = Array(stride(from:60,through:300,by:24))+Array(stride(from:420,through:780,by:120))
        let horizontals = Array(stride(from:180,through:660,by:120))+Array(stride(from:684,through:900,by:24))
        for y in 20..<920 { for x in 20..<880 {
            let xx = Double(x)-0.018*Double(y-420), yy = Double(y)+0.01*Double(x-540)
            let v = yy >= 160 && yy <= 920 && verticals.contains{abs(xx-Double($0))<1.2}
            let horizontal = xx >= 40 && xx <= 850 && horizontals.contains{abs(yy-Double($0))<1.2}
            p[y*w+x] = v || horizontal ? 115 : UInt8(175+x/100+y/160)
        } }
        let result = GridDetector.detect(GrayImage(width:w,height:h,pixels:p))
        let q = try XCTUnwrap(result.corner)
        XCTAssertNil(result.central)
        for (point,expectedX,expectedY) in [(q.topLeft,300.0,180.0),(q.topRight,780.0,180.0),
                                          (q.bottomLeft,300.0,660.0),(q.bottomRight,780.0,660.0)] {
            let px = point.x*Double(w), py = point.y*Double(h)
            XCTAssertEqual(px-0.018*(py-420),expectedX,accuracy:5)
            XCTAssertEqual(py+0.01*(px-540),expectedY,accuracy:5)
        }
    }

    func testDirectionalMedianMatchesOrderStatistic() {
        for a in 0...4 { for b in 0...4 { for c in 0...4 { for d in 0...4 { for e in 0...4 {
            let values = [a,b,c,d,e].map(Float.init)
            XCTAssertEqual(ImageMath.median5(values[0],values[1],values[2],values[3],values[4]),values.sorted()[2])
        } } } } }
    }

}
