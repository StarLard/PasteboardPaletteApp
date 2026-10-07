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
        _ = launchForUITesting()
    }

    /// Closing the main window must not quit the app (the menu bar extra keeps
    /// working), and the menu bar extra can bring the window back.
    @MainActor
    func testClosingWindowKeepsAppRunningAndMenuBarReopensIt() throws {
        let app = launchForUITesting()
        let window = app.windows["Pasteboard Palette"]

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
        let app = launchForUITesting()
        let window = app.windows["Pasteboard Palette"]

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

    /// Edits a snippet, searches, deletes, and returns to the empty state.
    @MainActor
    func testEditSearchAndDeleteSnippets() throws {
        let app = launchForUITesting()
        let window = app.windows["Pasteboard Palette"]

        XCTAssertTrue(window.staticTexts["No Snippets"].waitForExistence(timeout: 5), "Empty state")

        addSnippet(in: app, title: "Personal Email", text: "me@example.com")
        addSnippet(in: app, title: "Work Email", text: "me@work.example.com")

        // Edit: rename the work snippet.
        window.buttons["Work Email"].rightClick()
        window.menuItems["Edit…"].click()  // Scoped to the row's context menu
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let titleField = sheet.textFields.element(boundBy: 0)
        titleField.click()
        titleField.typeKey("a", modifierFlags: .command)
        titleField.typeText("Office Email")
        sheet.buttons["Save"].click()
        XCTAssertTrue(window.buttons["Office Email"].waitForExistence(timeout: 5))
        XCTAssertFalse(window.buttons["Work Email"].exists)

        // Search filters the list, and shows a no-results state.
        let search = window.searchFields.firstMatch
        search.click()
        search.typeText("office")
        XCTAssertTrue(window.buttons["Office Email"].waitForExistence(timeout: 5))
        XCTAssertFalse(window.buttons["Personal Email"].exists)
        search.typeKey("a", modifierFlags: .command)
        search.typeText("zzz")
        XCTAssertTrue(window.staticTexts["No Results for \u{201C}zzz\u{201D}"].waitForExistence(timeout: 5))
        search.typeKey("a", modifierFlags: .command)
        search.typeKey(.delete, modifierFlags: [])

        // Delete both snippets and return to the empty state.
        for title in ["Office Email", "Personal Email"] {
            let row = window.buttons[title]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.rightClick()
            window.menuItems["Delete"].click()  // Not Edit › Delete in the app menu
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
            wait(for: [gone], timeout: 5)
        }
        XCTAssertTrue(window.staticTexts["No Snippets"].waitForExistence(timeout: 5))
    }

    /// Pins and unpins from the menu bar's "Pinned Snippet" submenu.
    @MainActor
    func testPinFromMenuBarSubmenu() throws {
        let app = launchForUITesting()
        let window = app.windows["Pasteboard Palette"]

        addSnippet(in: app, title: "Personal Email", text: "me@example.com")
        addSnippet(in: app, title: "Work Email", text: "me@work.example.com")
        let personalRow = window.buttons["Personal Email"]
        let workRow = window.buttons["Work Email"]
        XCTAssertTrue(workRow.waitForExistence(timeout: 5))

        let statusItem = app.statusItems.firstMatch
        statusItem.click()
        let submenu = statusItem.menuItems["Pinned Snippet"]
        XCTAssertTrue(submenu.waitForExistence(timeout: 5))
        submenu.hover()
        let workChoice = submenu.menuItems["Work Email"]
        XCTAssertTrue(workChoice.waitForExistence(timeout: 5))
        workChoice.click()

        let movedUp = expectation(
            for: NSPredicate { _, _ in workRow.frame.minY < personalRow.frame.minY },
            evaluatedWith: nil
        )
        wait(for: [movedUp], timeout: 5)

        // "None" unpins, restoring the saved order.
        statusItem.click()
        XCTAssertTrue(submenu.waitForExistence(timeout: 5))
        submenu.hover()
        let noneChoice = submenu.menuItems["None"]
        XCTAssertTrue(noneChoice.waitForExistence(timeout: 5))
        noneChoice.click()

        let movedBack = expectation(
            for: NSPredicate { _, _ in personalRow.frame.minY < workRow.frame.minY },
            evaluatedWith: nil
        )
        wait(for: [movedBack], timeout: 5)
    }

    /// Opens Settings and checks its controls. Doesn't toggle them, since
    /// that would change real login items and preferences.
    @MainActor
    func testSettingsWindowShowsOptions() throws {
        let app = launchForUITesting()

        app.typeKey(",", modifierFlags: .command)

        // Match by label: grouped forms may render toggles as switches or checkboxes.
        for label in ["Launch at login", "Show in menu bar"] {
            let toggle = app.descendants(matching: .any)[label].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Missing \(label) toggle")
        }
    }

    /// Launches with an empty in-memory store, so every test starts from the
    /// same state. (Don't pass -ApplePersistenceIgnoreState: it suppresses the
    /// main window at launch.)
    @MainActor
    private func launchForUITesting() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(
            app.windows["Pasteboard Palette"].waitForExistence(timeout: 10),
            "Main window didn't appear. Windows: \(app.windows.debugDescription)"
        )
        return app
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
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
