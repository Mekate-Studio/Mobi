import XCTest

@MainActor final class PilotUITests: XCTestCase {
    func testRealNavigationRetryAndBackgroundForeground() {
        let app = XCUIApplication(bundleIdentifier: "studio.mekate.mobi")
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let allow = alert.buttons["Allow While Using App"]
            if allow.exists {
                allow.tap(); return true
            }
            return false
        }
        let clock = ContinuousClock()
        let start = clock.now
        app.launch()
        let nativeTab = app.tabBars.buttons["Native Home"]
        XCTAssertTrue(nativeTab.waitForExistence(timeout: 20))
        selectTab(nativeTab)
        let counter = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] 'Counter value:'")).firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        let initial = counter.label
        let refresh = app.buttons["Load next counter value"].firstMatch
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        refresh.tap()
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@ AND NOT label CONTAINS[c] 'loading'", initial),
            object: counter,
        )
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 20), .completed)
        let terminalValue = counter.label
        XCUIDevice.shared.press(.home)
        let background = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "state == %d", XCUIApplication.State.runningBackground.rawValue),
            object: app,
        )
        XCTAssertEqual(XCTWaiter.wait(for: [background], timeout: 10), .completed)
        app.activate()
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        XCTAssertEqual(counter.label, terminalValue)
        refresh.tap()
        let nearby = app.tabBars.buttons["Nearby Map"]
        nearby.tap()
        XCTAssertTrue(app.navigationBars["Nearby Map"].waitForExistence(timeout: 10))
        #if MOBI_PILOT_COMPOSE
            let shared = app.tabBars.buttons["Shared UI"]
            XCTAssertTrue(shared.exists)
            shared.tap()
            XCTAssertTrue(shared.isSelected)
        #else
            XCTAssertFalse(app.tabBars.buttons["Shared UI"].exists)
        #endif
        print("MOBI_PILOT_UI_NAVIGATION_DURATION=\(start.duration(to: clock.now))")
    }

    private func selectTab(_ tab: XCUIElement) {
        // A system interruption can consume the tap while its monitor handles
        // the permission prompt. Verify navigation and retry that tap once.
        for _ in 0 ..< 2 {
            tab.tap()
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "selected == true"),
                object: tab,
            )
            if XCTWaiter.wait(for: [selected], timeout: 2) == .completed {
                return
            }
        }
        XCTFail("Requested tab was not selected after handling interruptions")
    }
}
