import XCTest

final class cellscopeUITests: XCTestCase {
    @MainActor private func launchApp(language: String = "zh-Hans", arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "zh_CN"] + arguments
        app.launch(); return app
    }
    #if DEBUG
    @MainActor func testFaintCellsSensitivityAndPolarityUpdateLive() {
        let app = launchApp(arguments:["--ui-test-faint-cells"])
        XCTAssertTrue(app.staticTexts["cellCount"].waitForExistence(timeout:15))
        app.buttons["检测参数"].tap()
        let live = app.staticTexts["liveCellCount"]
        XCTAssertTrue(live.waitForExistence(timeout:5))
        func expect(_ count:Int) {
            let update = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","\(count) 个细胞"),object:live)
            XCTAssertEqual(XCTWaiter.wait(for:[update],timeout:20),.completed)
        }
        app.sliders["sensitivitySlider"].adjust(toNormalizedSliderPosition:0)
        expect(0)
        app.sliders["sensitivitySlider"].adjust(toNormalizedSliderPosition:1)
        expect(5)
        let polarity = app.segmentedControls["cellPolarityPicker"]
        polarity.buttons["深色"].tap();expect(2)
        polarity.buttons["浅色"].tap();expect(3)
        polarity.buttons["自动"].tap();expect(5)
        XCTAssertTrue(app.staticTexts["liveConcentration"].label.contains("10.00"))
        XCTAssertTrue(app.staticTexts["liveTotalCells"].label.contains("10.00"))
        app.buttons["resetDetectionSettings"].tap();expect(0)
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Faint-cell-live-settings";shot.lifetime = .keepAlways;add(shot)
    }
    @MainActor func testCentralGridDoesNotRestrictOverviewOrTenX() {
        for selectedMode in ["overview","singleLarge"] {
            let app = launchApp(arguments:["--ui-test-central-mode",selectedMode])
            let status = app.staticTexts.matching(identifier:"gridDetectionStatus").firstMatch
            let central = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","中央"),object:status)
            XCTAssertEqual(XCTWaiter.wait(for:[central],timeout:40),.completed)
            let counted = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label != %@","0"),object:app.staticTexts["cellCount"])
            XCTAssertEqual(XCTWaiter.wait(for:[counted],timeout:40),.completed)
            XCTAssertTrue(app.buttons["switchToRBC"].exists)
            XCTAssertTrue(app.buttons["detectCells"].isEnabled)
            if selectedMode == "overview" {
                XCTAssertTrue(app.staticTexts["gridArea"].label.contains("9"))
            } else { XCTAssertTrue(app.buttons["field-A1"].exists) }
            app.buttons["detectCells"].tap()
            let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:app.buttons["detectCells"])
            XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:40),.completed)
            let concentration = app.staticTexts["concentration"]
            for _ in 0..<6 where !concentration.isHittable { app.swipeUp() }
            XCTAssertTrue(concentration.exists)
            XCTAssertTrue(app.staticTexts["totalCells"].exists)
            XCTAssertTrue(app.buttons["saveRecord"].isEnabled)
            app.buttons["saveRecord"].tap(); app.alerts.buttons["确定"].tap()
            let savedCount = app.staticTexts["cellCount"].label
            app.tabBars.buttons["样本记录"].tap()
            let sample = selectedMode == "overview" ? "模拟样本 · 4× · 完整九宫格" : "模拟样本 · 10× · 单个大格"
            app.staticTexts.matching(identifier:sample).firstMatch.tap()
            app.buttons["载入样本"].tap()
            XCTAssertEqual(app.staticTexts["cellCount"].label,savedCount)
            if selectedMode == "singleLarge" { XCTAssertTrue(app.staticTexts["countedFields"].label.contains("1 / 4")) }
            XCTAssertTrue(app.staticTexts["concentration"].exists)
            app.terminate()
        }
    }
    #endif
    @MainActor func testChamberResetRestoresConcentrationAndTotal() {
        let app = launchApp()
        app.buttons["countingMode-custom"].tap(); app.buttons["loadDemo"].tap()
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","49"),object:app.staticTexts["cellCount"])
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
        func enter(_ id:String,_ value:String) {
            let field = app.textFields[id]
            for _ in 0..<5 where !field.isHittable { app.swipeUp() }
            field.tap()
            let old = field.value as? String ?? ""
            field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count)+value)
            let done = app.toolbars.buttons["完成"].firstMatch
            if done.exists { done.tap() }
        }
        enter("框选面积","2")
        enter("腔室深度","0.2")
        enter("总稀释倍数","5")
        enter("原液总体积","0.5")
        let reset = app.buttons["resetChamberParameters"]
        for _ in 0..<6 where !reset.isHittable { app.swipeDown() }
        reset.tap()
        XCTAssertEqual(app.textFields["框选面积"].value as? String,"1")
        XCTAssertEqual(app.textFields["腔室深度"].value as? String,"0.1")
        XCTAssertEqual(app.textFields["总稀释倍数"].value as? String,"2")
        XCTAssertEqual(app.textFields["原液总体积"].value as? String,"1")
        for _ in 0..<6 where !app.staticTexts["concentration"].isHittable { app.swipeUp() }
        XCTAssertEqual(app.staticTexts["concentration"].label,"98.00 × 10⁴")
        XCTAssertEqual(app.staticTexts["totalCells"].label,"98.00 × 10⁴")
    }
    @MainActor func testEnglishInterfaceAndCredits() {
        let app = launchApp(language:"en")
        app.buttons["countingMode-custom"].tap(); app.buttons["loadDemo"].tap()
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","49"),object:app.staticTexts["cellCount"])
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
        XCTAssertTrue(app.tabBars.buttons["Cell count"].exists)
        app.buttons["Detection settings"].tap()
        XCTAssertTrue(app.staticTexts["liveCellCount"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["liveCellCount"].label,"49 cells")
        XCTAssertTrue(app.switches["automaticSizeToggle"].label.contains("Estimate"))
        let image = XCTAttachment(screenshot:app.screenshot()); image.name = "cellscope-English"; image.lifetime = .keepAlways; add(image)
        app.navigationBars.buttons["Done"].tap()
        app.tabBars.buttons["User guide"].tap()
        let credit = app.staticTexts["coauthorCredit"]
        for _ in 0..<8 where !credit.isHittable { app.swipeUp() }
        XCTAssertTrue(credit.label.contains("Codex GPT-6.1 Sol"))
    }
    @MainActor private func visible(_ query: XCUIElementQuery) -> XCUIElement {
        query.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? query.firstMatch
    }
    @MainActor func testAutomaticBorderCalculatesWithoutConfirmations() {
        let app = launchApp()
        app.buttons["loadDemo"].tap()
        let count = app.staticTexts["cellCount"]
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@", "49"),object:count)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
        app.buttons["locateGrid"].tap()
        let status = app.staticTexts.matching(identifier:"gridDetectionStatus").firstMatch
        let aligned = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@", "4×4"),object:status)
        XCTAssertEqual(XCTWaiter.wait(for:[aligned],timeout:20),.completed)
        let recounted = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@", "49"),object:count)
        XCTAssertEqual(XCTWaiter.wait(for:[recounted],timeout:20),.completed)
        XCTAssertFalse(app.switches["confirmArea"].exists)
        XCTAssertFalse(app.switches["已逐一复核细胞标记"].exists)
        let concentration = app.staticTexts["concentration"]
        for _ in 0..<6 where !concentration.isHittable { app.swipeUp() }
        XCTAssertEqual(concentration.label,"98.00 × 10⁴")
        XCTAssertTrue(app.buttons["saveRecord"].isEnabled)
    }
    @MainActor func testLiveParametersUpdateImageCountAndCalculation() {
        let app = launchApp()
        app.buttons["countingMode-custom"].tap(); app.buttons["loadDemo"].tap()
        let first = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","49"),object:app.staticTexts["cellCount"])
        XCTAssertEqual(XCTWaiter.wait(for:[first],timeout:20),.completed)
        app.buttons["检测参数"].tap()
        let live = app.staticTexts["liveCellCount"]
        XCTAssertTrue(live.waitForExistence(timeout:5))
        let automatic = app.switches["automaticSizeToggle"]
        automatic.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
        XCTAssertEqual(automatic.value as? String,"0")
        let maximum = app.sliders["maximumDiameterSlider"]
        for _ in 0..<4 where !maximum.isHittable { visible(app.collectionViews).swipeUp() }
        maximum.adjust(toNormalizedSliderPosition:1)
        let minimum = app.sliders["minimumDiameterSlider"]
        minimum.adjust(toNormalizedSliderPosition:1)
        let zero = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","0 个细胞"),object:live)
        XCTAssertEqual(XCTWaiter.wait(for:[zero],timeout:20),.completed)
        XCTAssertTrue(app.staticTexts["liveConcentration"].label.contains("0"))
        app.buttons["resetDetectionSettings"].tap()
        XCTAssertEqual(automatic.value as? String,"1")
        let recovered = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","49 个细胞"),object:live)
        XCTAssertEqual(XCTWaiter.wait(for:[recovered],timeout:20),.completed)
        XCTAssertTrue(app.staticTexts["liveConcentration"].label.contains("98.00"))
        XCTAssertTrue(app.staticTexts["liveTotalCells"].label.contains("98.00"))
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Live-parameters"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons["完成"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }
    @MainActor func testFrameHandlesDragNudgeAndRecount() {
        let app = launchApp()
        app.buttons["countingMode-custom"].tap(); app.buttons["loadDemo"].tap()
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","49"),object:app.staticTexts["cellCount"])
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed)
        app.buttons["mode-region"].tap()
        let handle = visible(app.buttons.matching(identifier:"frameHandle-0"))
        XCTAssertTrue(handle.waitForExistence(timeout:5))
        let start = handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.1,thenDragTo:start.withOffset(CGVector(dx:90,dy:90)))
        let changed = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label != %@","49 个细胞"),object:app.staticTexts["fullscreenCount"])
        XCTAssertEqual(XCTWaiter.wait(for:[changed],timeout:20),.completed)
        XCTAssertTrue(app.buttons["nudge-arrow.right"].isHittable)
        app.buttons["nudge-arrow.right"].tap()
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "Frame-handles"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["重置边框"].tap()
        let restored = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","49 个细胞"),object:app.staticTexts["fullscreenCount"])
        XCTAssertEqual(XCTWaiter.wait(for:[restored],timeout:20),.completed)
        app.navigationBars.buttons["完成"].tap()
    }
    @MainActor func testDemoCountingCorrectionCalculationAndHistory() {
        let app = launchApp()
        app.buttons["countingMode-custom"].tap()
        XCTAssertTrue(app.buttons["loadDemo"].waitForExistence(timeout: 10))
        app.buttons["loadDemo"].tap()
        let count = app.staticTexts["cellCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 15))
        let finished = NSPredicate(format: "label == %@", "49")
        expectation(for: finished, evaluatedWith: count)
        waitForExpectations(timeout: 15)
        app.buttons["全屏查看"].tap()
        XCTAssertTrue(app.staticTexts["fullscreenCount"].waitForExistence(timeout: 5))
        let detection = XCTAttachment(screenshot: app.screenshot())
        detection.name = "Detection"; detection.lifetime = .keepAlways; add(detection)
        visible(app.buttons.matching(identifier: "mode-remove")).tap()
        let canvas = visible(app.scrollViews.matching(identifier: "imageCanvas"))
        let frame = canvas.frame
        let side = min(frame.width, frame.height)
        let firstCell = canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: (frame.width - side) / 2 + side * 0.15,
            dy: (frame.height - side) / 2 + side * 0.15))
        firstCell.tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "48 个细胞")
        visible(app.buttons.matching(identifier: "撤销标记修改")).tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "49 个细胞")
        visible(app.buttons.matching(identifier: "mode-add")).tap()
        canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: (frame.width - side) / 2 + side * 0.2,
            dy: (frame.height - side) / 2 + side * 0.2)).tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "50 个细胞")
        visible(app.buttons.matching(identifier: "撤销标记修改")).tap()
        app.navigationBars.buttons["完成"].tap()
        for _ in 0..<6 where !app.staticTexts["concentration"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["concentration"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["concentration"].label, "98.00 × 10⁴")
        XCTAssertTrue(app.staticTexts["requiredVolume"].label.contains("102.04"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Calculation"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["saveRecord"].tap()
        app.alerts.buttons["确定"].tap()
        app.tabBars.buttons["样本记录"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "模拟样本 · 49 个细胞").firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["样本记录"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "模拟样本 · 49 个细胞").firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testNeubauerModesAndFourCornerMean() {
        let app = launchApp()
        app.buttons["countingMode-overview"].tap()
        app.buttons["loadDemo"].tap()
        func expectCount(_ value: String) {
            let predicate = NSPredicate(format: "label == %@", value)
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.staticTexts["cellCount"])
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed)
        }
        func captureTemplate(_ name: String) {
            app.buttons["全屏查看"].tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            app.navigationBars.buttons["完成"].tap()
        }
        expectCount("81")
        captureTemplate("Neubauer-4x")
        app.buttons["selectStandardSquares"].tap()
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
        app.buttons["全屏查看"].tap()
        visible(app.buttons.matching(identifier: "mode-remove")).tap()
        let canvas = visible(app.scrollViews.matching(identifier: "imageCanvas"))
        let frame = canvas.frame, side = min(canvas.frame.width, canvas.frame.height)
        canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: (frame.width - side) / 2 + side * 0.15,
            dy: (frame.height - side) / 2 + side * 0.15)).tap()
        XCTAssertEqual(app.staticTexts["fullscreenCount"].label, "48 个细胞")
        app.navigationBars.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["fourFieldMean"].label.contains("48.75"))
        for _ in 0..<6 where !app.staticTexts["concentration"].isHittable { app.swipeUp() }
        XCTAssertEqual(app.staticTexts["concentration"].label, "97.50 × 10⁴")
        XCTAssertTrue(app.buttons["saveRecord"].isEnabled)
        app.buttons["saveRecord"].tap(); app.alerts.buttons["确定"].tap()
        app.terminate(); app.launch()
        app.tabBars.buttons["样本记录"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "模拟样本 · 10× · 单个大格").firstMatch.waitForExistence(timeout: 5))
    }
}
