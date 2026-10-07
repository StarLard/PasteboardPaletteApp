//
//  PasteboardPaletteTests.swift
//  Pasteboard PaletteTests
//
//  Created by Caleb Friden on 10/6/26.
//

import AppKit
import Foundation
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

/// Builds a store backed by throwaway `UserDefaults`, a private pasteboard, and
/// a test clock, so tests never touch the user's real data or the general pasteboard.
@MainActor
private struct Fixture {
    let suiteName = "PasteboardPaletteTests-\(UUID().uuidString)"
    let defaults: UserDefaults
    let pasteboard = NSPasteboard.withUniqueName()
    let clock = TestClock()

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    func makeStore() -> SnippetStore {
        SnippetStore(defaults: defaults, pasteboard: pasteboard, now: { [clock] in clock.date })
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        pasteboard.releaseGlobally()
    }
}

@MainActor
@Suite("SnippetStore")
struct SnippetStoreTests {
    @Test func addAppendsSnippetWithoutPinningIt() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()

        let first = try #require(store.add(title: " Email ", text: "me@example.com"))
        let second = try #require(store.add(text: "second"))

        #expect(store.snippets.map(\.id) == [first.id, second.id])
        #expect(first.title == "Email")
        #expect(store.pinnedSnippetID == nil)
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func addIgnoresBlankText(_ text: String) {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()

        #expect(store.add(text: text) == nil)
        #expect(store.snippets.isEmpty)
    }

    @Test func deletingPinnedSnippetUnpinsIt() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let first = try #require(store.add(text: "one"))
        let second = try #require(store.add(text: "two"))
        store.pin(first)

        store.delete(first)

        #expect(store.pinnedSnippetID == nil)
        #expect(store.snippets.map(\.id) == [second.id])
    }

    @Test func pinReplacesPreviousPinAndIgnoresUnknownIDs() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let first = try #require(store.add(text: "one"))
        let second = try #require(store.add(text: "two"))

        store.pin(first)
        store.pin(second)
        #expect(store.pinnedSnippet == second)
        #expect(store.isPinned(second))
        #expect(!store.isPinned(first))

        store.setPinned(id: UUID())
        #expect(store.pinnedSnippetID == second.id)

        store.unpin()
        #expect(store.pinnedSnippet == nil)
    }

    @Test func orderedSnippetsPutsPinnedFirstWithoutChangingSavedOrder() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let a = try #require(store.add(text: "a"))
        let b = try #require(store.add(text: "b"))
        let c = try #require(store.add(text: "c"))

        store.pin(c)
        #expect(store.orderedSnippets.map(\.id) == [c.id, a.id, b.id])

        // Unpinning returns the snippet to its original position.
        store.unpin()
        #expect(store.orderedSnippets.map(\.id) == [a.id, b.id, c.id])
    }

    @Test func moveKeepsPinnedSnippetFirst() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let a = try #require(store.add(text: "a"))
        let b = try #require(store.add(text: "b"))
        let c = try #require(store.add(text: "c"))
        store.pin(b)
        // Display order is now [b, a, c]. Drag "c" above the pinned row.
        store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(store.orderedSnippets.map(\.id) == [b.id, c.id, a.id])
    }

    @Test func updateReplacesSnippet() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        var snippet = try #require(store.add(text: "old"))

        snippet.text = "new"
        store.update(snippet)

        #expect(store.snippets.first?.text == "new")
    }

    @Test func moveReordersSnippets() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let a = try #require(store.add(text: "a"))
        let b = try #require(store.add(text: "b"))
        let c = try #require(store.add(text: "c"))

        store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(store.snippets.map(\.id) == [c.id, a.id, b.id])
    }

    @Test func persistsAcrossInstances() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        _ = try #require(store.add(title: "Email", text: "me@example.com"))
        let second = try #require(store.add(text: "other"))
        store.pin(second)

        let reloaded = fixture.makeStore()

        #expect(reloaded.snippets == store.snippets)
        #expect(reloaded.pinnedSnippetID == second.id)
    }

    @Test func copyWritesToPasteboardAndPublishesFeedback() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let snippet = try #require(store.add(text: "me@example.com"))

        store.copy(snippet)

        #expect(fixture.pasteboard.string(forType: .string) == "me@example.com")
        #expect(store.copyFeedback?.snippetID == snippet.id)
    }

    @Test func copyRecordsLastUsedDate() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let snippet = try #require(store.add(text: "x"))
        #expect(store.snippets.first?.lastUsedAt == nil)

        fixture.clock.advance(by: 60)
        store.copy(snippet)

        #expect(store.snippets.first?.lastUsedAt == fixture.clock.date)
        #expect(fixture.makeStore().snippets.first?.lastUsedAt == fixture.clock.date, "Persisted")
    }

    @Test func updateDoesNotRollBackLastUsedDate() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        var staleCopy = try #require(store.add(text: "old"))
        fixture.clock.advance()
        store.copy(staleCopy)

        staleCopy.text = "new"
        store.update(staleCopy)

        #expect(store.snippets.first?.text == "new")
        #expect(store.snippets.first?.lastUsedAt == fixture.clock.date)
    }

    @Test func recentSnippetsAreUnpinnedMostRecentlyUsedFirstAndLimited() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        var added: [Snippet] = []
        for name in ["a", "b", "c", "d", "e"] {
            fixture.clock.advance()
            added.append(try #require(store.add(text: name)))
        }
        let (a, b, c, d, e) = (added[0], added[1], added[2], added[3], added[4])

        // Never-copied snippets count as used when created: newest first.
        #expect(store.recentSnippets().map(\.id) == [e.id, d.id, c.id])

        // Copying moves a snippet to the front.
        fixture.clock.advance()
        store.copy(a)
        fixture.clock.advance()
        store.copy(b)
        #expect(store.recentSnippets().map(\.id) == [b.id, a.id, e.id])

        // The pinned snippet is never listed among recents.
        store.pin(b)
        #expect(store.recentSnippets().map(\.id) == [a.id, e.id, d.id])

        #expect(store.recentSnippets(limit: 10).count == 4)
        #expect(SnippetStore.menuBarRecentLimit == 3)
    }

    @Test func repeatedCopiesProduceNewFeedbackTokens() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let snippet = try #require(store.add(text: "x"))

        store.copy(snippet)
        let firstToken = store.copyFeedback?.token
        store.copy(snippet)

        #expect(store.copyFeedback?.token != firstToken)
    }

    @Test func addFromPasteboardSavesPasteboardText() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        fixture.pasteboard.clearContents()
        fixture.pasteboard.setString("from pasteboard", forType: .string)

        let snippet = try #require(store.addFromPasteboard())

        #expect(snippet.text == "from pasteboard")
        #expect(store.snippets.count == 1)
    }

    @Test func addPastedSkipsBlankStrings() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()

        store.add(pasted: ["one", "  ", "two"])

        #expect(store.snippets.map(\.text) == ["one", "two"])
    }
}

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
