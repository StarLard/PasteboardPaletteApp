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

    /// Adds two snippets, pins the second from its context menu, and checks it
    /// moves to the top of both the app's list and the menu bar menu.
    @MainActor
    func testPinnedSnippetStaysOnTop() throws {
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
        XCTAssertLessThan(personalRow.frame.minY, workRow.frame.minY, "Unpinned snippets keep their saved order")

        // Clicking a row copies it (and must not crash or open anything).
        personalRow.click()

        // Pin the second snippet from its context menu.
        workRow.rightClick()
        let pinItem = app.menuItems["Pin"]
        XCTAssertTrue(pinItem.waitForExistence(timeout: 5))
        pinItem.click()

        // It moves to the top of the list…
        let movedUp = expectation(
            for: NSPredicate { _, _ in workRow.frame.minY < personalRow.frame.minY },
            evaluatedWith: nil
        )
        wait(for: [movedUp], timeout: 5)

        // …and to the top of the menu bar menu.
        let statusItem = app.statusItems.firstMatch
        statusItem.click()
        XCTAssertTrue(statusItem.menuItems["Work Email"].waitForExistence(timeout: 5))
        // Ignore section headers and commands, and take the first two matches:
        // the top-level items. (The "Pinned Snippet" submenu lists them again.)
        let snippetTitles = statusItem.menuItems.allElementsBoundByIndex
            .map(\.title)
            .filter { ["Personal Email", "Work Email"].contains($0) }
        XCTAssertEqual(Array(snippetTitles.prefix(2)), ["Work Email", "Personal Email"])
        app.typeKey(.escape, modifierFlags: [])

        // Unpinning restores the saved order.
        workRow.rightClick()
        let unpinItem = app.menuItems["Unpin"]
        XCTAssertTrue(unpinItem.waitForExistence(timeout: 5))
        unpinItem.click()

        let movedBack = expectation(
            for: NSPredicate { _, _ in personalRow.frame.minY < workRow.frame.minY },
            evaluatedWith: nil
        )
        wait(for: [movedBack], timeout: 5)
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
