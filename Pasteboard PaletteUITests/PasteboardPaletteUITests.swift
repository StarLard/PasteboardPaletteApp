//
//  PasteboardPaletteUITests.swift
//  Pasteboard PaletteUITests
//
//  Created by Caleb Friden on 10/6/26.
//

import XCTest

final class PasteboardPaletteUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsMainWindow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows["Pasteboard Palette"].waitForExistence(timeout: 5))
    }

    /// Closing the main window must not quit the app (the menu bar extra keeps
    /// working), and the menu bar extra can bring the window back.
    @MainActor
    func testClosingWindowKeepsAppRunningAndMenuBarReopensIt() throws {
        let app = XCUIApplication()
        app.launch()

        let window = app.windows["Pasteboard Palette"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        window.buttons[XCUIIdentifierCloseWindow].click()
        let windowGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: window)
        wait(for: [windowGone], timeout: 5)
        XCTAssertNotEqual(app.state, .notRunning)

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let openItem = app.menuItems["Open Pasteboard Palette"]
        XCTAssertTrue(openItem.waitForExistence(timeout: 5))
        openItem.click()

        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Opening again while the window is visible must not create a duplicate.
        statusItem.click()
        XCTAssertTrue(openItem.waitForExistence(timeout: 5))
        openItem.click()
        XCTAssertEqual(app.windows.matching(NSPredicate(format: "title == %@", "Pasteboard Palette")).count, 1)
    }

    /// Adds two snippets, checks the first becomes the menu bar snippet, then
    /// switches the menu bar snippet from the row's context menu.
    @MainActor
    func testAddSnippetsAndChooseMenuBarSnippet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let window = app.windows["Pasteboard Palette"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        addSnippet(in: app, title: "Personal Email", text: "me@example.com")
        addSnippet(in: app, title: "Work Email", text: "me@work.example.com")

        let personalRow = window.buttons["Personal Email"]
        let workRow = window.buttons["Work Email"]
        XCTAssertTrue(personalRow.waitForExistence(timeout: 5))
        XCTAssertTrue(workRow.exists)

        // Clicking a row copies it (and must not crash or open anything).
        personalRow.click()

        // The first snippet added is the menu bar snippet.
        let statusItem = app.statusItems.firstMatch
        statusItem.click()
        XCTAssertTrue(app.menuItems["Copy \u{201C}Personal Email\u{201D}"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])

        // Switch it from the row's context menu.
        workRow.rightClick()
        let useInMenuBar = app.menuItems["Use in Menu Bar"]
        XCTAssertTrue(useInMenuBar.waitForExistence(timeout: 5))
        useInMenuBar.click()

        statusItem.click()
        XCTAssertTrue(app.menuItems["Copy \u{201C}Work Email\u{201D}"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    private func addSnippet(in app: XCUIApplication, title: String, text: String) {
        app.typeKey("n", modifierFlags: .command)

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))

        let fields = sheet.textFields
        fields.element(boundBy: 0).click()
        fields.element(boundBy: 0).typeText(title)
        fields.element(boundBy: 1).click()
        fields.element(boundBy: 1).typeText(text)

        sheet.buttons["Save"].click()
        let sheetGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheet)
        wait(for: [sheetGone], timeout: 5)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
