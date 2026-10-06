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

/// Builds a store backed by throwaway `UserDefaults` and a private pasteboard,
/// so tests never touch the user's real data or the general pasteboard.
@MainActor
private struct Fixture {
    let suiteName = "PasteboardPaletteTests-\(UUID().uuidString)"
    let defaults: UserDefaults
    let pasteboard = NSPasteboard.withUniqueName()

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    func makeStore() -> SnippetStore {
        SnippetStore(defaults: defaults, pasteboard: pasteboard)
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
