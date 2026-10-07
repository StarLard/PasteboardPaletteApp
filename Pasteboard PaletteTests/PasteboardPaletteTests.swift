//
//  PasteboardPaletteTests.swift
//  Pasteboard PaletteTests
//
//  Created by Caleb Friden on 10/6/26.
//

import AppKit
import Foundation
import SwiftData
import Testing
@testable import PasteboardPalette

/// A manually advanced clock, so timestamps in tests are deterministic.
@MainActor
private final class TestClock {
    var date = Date(timeIntervalSinceReferenceDate: 0)

    func advance(by seconds: TimeInterval = 1) {
        date += seconds
    }
}

/// An in-memory SwiftData container, a private pasteboard, and a test clock,
/// so tests never touch the user's real data or the general pasteboard.
@MainActor
private struct Fixture {
    let container: ModelContainer
    let rawPasteboard = NSPasteboard.withUniqueName()
    let clock = TestClock()
    let pasteboard: PasteboardController

    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Snippet.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        pasteboard = PasteboardController(pasteboard: rawPasteboard, now: { [clock] in clock.date })
    }

    /// Adds a snippet, advancing the clock first so creation dates are distinct.
    @discardableResult
    func add(_ text: String, title: String = "") throws -> Snippet {
        clock.advance()
        return try #require(context.addSnippet(title: title, text: text, now: clock.date))
    }

    func tearDown() {
        rawPasteboard.releaseGlobally()
    }
}

@MainActor
@Suite("Adding, editing, and deleting")
struct EditingTests {
    @Test func addAppendsInOrderWithoutPinning() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }

        let first = try fixture.add("me@example.com", title: " Email ")
        let second = try fixture.add("second")

        #expect(fixture.context.allSnippets() == [first, second])
        #expect(first.title == "Email")
        #expect(!first.isPinned && !second.isPinned)
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func addIgnoresBlankText(_ text: String) throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }

        #expect(fixture.context.addSnippet(text: text) == nil)
        #expect(fixture.context.allSnippets().isEmpty)
    }

    @Test func addPastedSkipsBlankStrings() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }

        fixture.context.addSnippets(pasted: ["one", "  ", "two"])

        #expect(fixture.context.allSnippets().map(\.text) == ["one", "two"])
    }

    @Test func updateStampsEditedDateOnlyWhenContentChanges() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let snippet = try fixture.add("a@example.com", title: "Email")

        fixture.clock.advance()
        snippet.update(title: "Email", text: "a@example.com", now: fixture.clock.date)
        #expect(snippet.editedAt == nil, "No-op saves don't count as edits")

        fixture.clock.advance()
        snippet.update(title: " Email ", text: "b@example.com", now: fixture.clock.date)
        #expect(snippet.text == "b@example.com")
        #expect(snippet.title == "Email")
        #expect(snippet.editedAt == fixture.clock.date)
    }

    @Test func deletingPinnedSnippetLeavesNothingPinned() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let first = try fixture.add("one")
        let second = try fixture.add("two")
        fixture.context.pin(first)

        fixture.context.delete(first)

        #expect(fixture.context.allSnippets() == [second])
        #expect(!second.isPinned)
    }

    @Test func persistsAcrossContainers() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "PasteboardPaletteTests-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
            }
        }

        do {
            let container = try ModelContainer(for: Snippet.self, configurations: ModelConfiguration(url: url))
            let snippet = try #require(container.mainContext.addSnippet(title: "Email", text: "me@example.com"))
            container.mainContext.pin(snippet)
            try container.mainContext.save()
        }

        let reopened = try ModelContainer(for: Snippet.self, configurations: ModelConfiguration(url: url))
        let snippets = reopened.mainContext.allSnippets()
        #expect(snippets.map(\.text) == ["me@example.com"])
        #expect(snippets.first?.isPinned == true)
    }
}

@MainActor
@Suite("Pinning and ordering")
struct OrderingTests {
    @Test func pinReplacesPreviousPin() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let first = try fixture.add("one")
        let second = try fixture.add("two")

        fixture.context.pin(first)
        fixture.context.pin(second)
        #expect(!first.isPinned && second.isPinned)

        fixture.context.unpinAll()
        #expect(!first.isPinned && !second.isPinned)
    }

    @Test func pinnedFirstKeepsManualOrderAndRestoresItOnUnpin() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let a = try fixture.add("a")
        let b = try fixture.add("b")
        let c = try fixture.add("c")

        fixture.context.pin(c)
        #expect(Snippet.pinnedFirst(fixture.context.allSnippets()) == [c, a, b])

        c.isPinned = false
        #expect(Snippet.pinnedFirst(fixture.context.allSnippets()) == [a, b, c])
    }

    @Test func moveReordersSnippets() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let a = try fixture.add("a")
        let b = try fixture.add("b")
        let c = try fixture.add("c")

        fixture.context.moveSnippets(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(fixture.context.allSnippets() == [c, a, b])
    }

    @Test func moveKeepsPinnedSnippetFirst() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let a = try fixture.add("a")
        let b = try fixture.add("b")
        let c = try fixture.add("c")
        fixture.context.pin(b)

        // Display order is [b, a, c]. Drag "c" above the pinned row.
        fixture.context.moveSnippets(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(Snippet.pinnedFirst(fixture.context.allSnippets()) == [b, c, a])
    }

    @Test func recentsAreUnpinnedMostRecentlyUsedFirstAndLimited() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let a = try fixture.add("a")
        let b = try fixture.add("b")
        let c = try fixture.add("c")
        let d = try fixture.add("d")
        let e = try fixture.add("e")
        func recents() -> [Snippet] { Snippet.recents(in: fixture.context.allSnippets()) }

        // Never-copied snippets order by creation, newest first.
        #expect(recents() == [e, d, c])

        // Copying moves a snippet to the front.
        fixture.clock.advance()
        fixture.pasteboard.copy(a)
        fixture.clock.advance()
        fixture.pasteboard.copy(b)
        #expect(recents() == [b, a, e])

        // The pinned snippet is never listed among recents.
        fixture.context.pin(b)
        #expect(recents() == [a, e, d])

        #expect(Snippet.recents(in: fixture.context.allSnippets(), limit: 10).count == 4)
        #expect(Snippet.menuBarRecentLimit == 3)
    }

    @Test func neverUsedSnippetsAreOrderedByEditThenCreation() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let a = try fixture.add("a")
        let b = try fixture.add("b")
        let c = try fixture.add("c")
        let d = try fixture.add("d")
        func recents() -> [Snippet] { Snippet.recents(in: fixture.context.allSnippets()) }

        // Editing the oldest snippet makes it the most recent unused one.
        fixture.clock.advance()
        a.update(title: "", text: "a, edited", now: fixture.clock.date)
        #expect(recents() == [a, d, c])

        // Once used, a snippet orders by last use, even if edited before that.
        fixture.clock.advance()
        fixture.pasteboard.copy(b)
        #expect(recents() == [b, a, d])
    }
}

@MainActor
@Suite("PasteboardController")
struct PasteboardControllerTests {
    @Test func copyWritesToPasteboardRecordsUseAndPublishesFeedback() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let snippet = try fixture.add("me@example.com")
        let other = try fixture.add("other")

        fixture.clock.advance(by: 60)
        fixture.pasteboard.copy(snippet)

        #expect(fixture.rawPasteboard.string(forType: .string) == "me@example.com")
        #expect(snippet.lastUsedAt == fixture.clock.date)
        #expect(fixture.pasteboard.feedbackToken(for: snippet) != nil)
        #expect(fixture.pasteboard.feedbackToken(for: other) == nil)
    }

    @Test func repeatedCopiesProduceNewFeedbackTokens() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        let snippet = try fixture.add("x")

        fixture.pasteboard.copy(snippet)
        let firstToken = fixture.pasteboard.feedbackToken(for: snippet)
        fixture.pasteboard.copy(snippet)

        #expect(fixture.pasteboard.feedbackToken(for: snippet) != firstToken)
    }

    @Test func readStringReturnsPasteboardText() throws {
        let fixture = try Fixture()
        defer { fixture.tearDown() }
        fixture.rawPasteboard.clearContents()
        fixture.rawPasteboard.setString("from pasteboard", forType: .string)

        #expect(fixture.pasteboard.readString() == "from pasteboard")
    }
}

@MainActor
@Suite("Snippet")
struct SnippetTests {
    @Test func displayTitlePrefersTitle() {
        #expect(Snippet(title: "Email", text: "me@example.com").displayTitle == "Email")
    }

    @Test func displayTitleFallsBackToFirstNonEmptyLine() {
        let snippet = Snippet(title: "   ", text: "\n  first line  \nsecond line")
        #expect(snippet.displayTitle == "first line")
    }

    @Test func displayTitleFallsBackToUntitled() {
        #expect(Snippet(text: "  \n ").displayTitle == "Untitled")
    }
}
