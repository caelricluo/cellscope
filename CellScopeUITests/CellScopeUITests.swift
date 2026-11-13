import XCTest

final class CellScopeUITests: XCTestCase {
    @MainActor private func visible(_ query: XCUIElementQuery) -> XCUIElement {
        query.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? query.firstMatch
    }
    @MainActor func testAutomaticBorderRequiresFreshAreaConfirmation() {
        let app = XCUIApplication(); app.launch()
        app.buttons["loadDemo"].tap()
        let count = app.staticTexts["cellCount"]
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@", "49"),object:count)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
        app.buttons["locateGrid"].tap()
        app.buttons["重新定位边框"].tap()
        let status = app.staticTexts.matching(identifier:"gridDetectionStatus").firstMatch
        let aligned = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@", "4×4"),object:status)
        XCTAssertEqual(XCTWaiter.wait(for:[aligned],timeout:20),.completed)
        let recounted = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@", "49"),object:count)
        XCTAssertEqual(XCTWaiter.wait(for:[recounted],timeout:20),.completed)
        let confirm = app.switches["confirmArea"]
        for _ in 0..<6 where !confirm.isHittable { app.swipeUp() }
        XCTAssertEqual(confirm.value as? String,"0")
        XCTAssertFalse(app.staticTexts["concentration"].exists)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["fourFieldMean"].exists)
    }
    @MainActor func testDemoCountingCorrectionCalculationAndHistory() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["countingMode-custom"].tap()
        XCTAssertTrue(app.buttons["loadDemo"].waitForExistence(timeout: 10))
        app.buttons["loadDemo"].tap()
        let count = app.staticTexts["cellCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 15))
        let finished = NSPredicate(format: "label == %@", "49")
        expectation(for: finished, evaluatedWith: count)
        waitForExpectations(timeout: 15)
        app.buttons["全屏复核"].tap()
        XCTAssertTrue(app.staticTexts["fullscreenCount"].waitForExistence(timeout: 5))
        let detection = XCTAttachment(screenshot: app.screenshot())
        detection.name = "Detection"; detection.lifetime = .keepAlways; add(detection)
        visible(app.buttons.matching(identifier: "mode-删除")).tap()
        let canvas = visible(app.scrollViews.matching(identifier: "imageCanvas"))
        let frame = canvas.frame
        let side = min(frame.width, frame.height)
        let firstCell = canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: (frame.width - side) / 2 + side * 0.15,
            dy: (frame.height - side) / 2 + side * 0.15))
        firstCell.tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "48 个候选细胞")
        visible(app.buttons.matching(identifier: "撤销标记修改")).tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "49 个候选细胞")
        visible(app.buttons.matching(identifier: "mode-补标")).tap()
        canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: (frame.width - side) / 2 + side * 0.2,
            dy: (frame.height - side) / 2 + side * 0.2)).tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "50 个候选细胞")
        visible(app.buttons.matching(identifier: "撤销标记修改")).tap()
        app.navigationBars.buttons["完成"].tap()
        app.swipeUp()
        let reviewed = app.switches["已逐一复核细胞标记"]
        XCTAssertTrue(reviewed.waitForExistence(timeout: 5))
        if reviewed.value as? String != "1" { reviewed.tap() }
        for _ in 0..<3 { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["concentration"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["concentration"].label, "98.00 × 10⁴")
        XCTAssertTrue(app.staticTexts["requiredVolume"].label.contains("102.04"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Calculation"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["saveRecord"].tap()
        app.alerts.buttons["知道了"].tap()
        app.tabBars.buttons["样本记录"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "模拟样本 · 49 个细胞").firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["样本记录"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "模拟样本 · 49 个细胞").firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testNeubauerModesAndFourCornerMean() {
        let app = XCUIApplication(); app.launch()
        app.buttons["countingMode-overview"].tap()
        app.buttons["loadDemo"].tap()
        func expectCount(_ value: String) {
            let predicate = NSPredicate(format: "label == %@", value)
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.staticTexts["cellCount"])
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed)
        }
        func captureTemplate(_ name: String) {
            app.buttons["全屏复核"].tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            app.navigationBars.buttons["完成"].tap()
        }
        expectCount("81")
        captureTemplate("Neubauer-4x")
        app.buttons["selectStandardSquares"].tap()
        app.buttons["detectCells"].tap()
        expectCount("36")
        for _ in 0..<5 { app.swipeDown() }
        app.buttons["countingMode-redBloodCells"].tap()
        expectCount("20")
        captureTemplate("Neubauer-RBC")
        for _ in 0..<5 { app.swipeDown() }
        app.buttons["countingMode-singleLarge"].tap()
        expectCount("49")
        XCTAssertTrue(app.staticTexts["fourFieldMean"].label.contains("196"))
        XCTAssertTrue(app.staticTexts["fourFieldMean"].label.contains("49"))
        app.buttons["全屏复核"].tap()
        visible(app.buttons.matching(identifier: "mode-删除")).tap()
        let canvas = visible(app.scrollViews.matching(identifier: "imageCanvas"))
        let frame = canvas.frame, side = min(canvas.frame.width, canvas.frame.height)
        canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: (frame.width - side) / 2 + side * 0.15,
            dy: (frame.height - side) / 2 + side * 0.15)).tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "48 个候选细胞")
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["fourFieldMean"].label.contains("48.75"))
        for field in ["A1", "A3", "C1", "C3"] {
            for _ in 0..<5 { app.swipeDown() }
            app.buttons["field-\(field)"].tap()
            let reviewed = app.switches["已逐一复核细胞标记"]
            for _ in 0..<5 where !reviewed.isHittable { app.swipeUp() }
            if reviewed.value as? String != "1" { reviewed.tap() }
        }
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertEqual(app.staticTexts["concentration"].label, "97.50 × 10⁴")
        XCTAssertTrue(app.buttons["saveRecord"].isEnabled)
        app.buttons["saveRecord"].tap(); app.alerts.buttons["知道了"].tap()
        app.terminate(); app.launch()
        app.tabBars.buttons["样本记录"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "模拟样本 · 10× · 单个大格").firstMatch.waitForExistence(timeout: 5))
    }
}
