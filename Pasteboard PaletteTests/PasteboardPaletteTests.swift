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
    @Test func addAppendsSnippetAndFirstBecomesActive() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()

        let first = try #require(store.add(title: " Email ", text: "me@example.com"))
        let second = try #require(store.add(text: "second"))

        #expect(store.snippets.map(\.id) == [first.id, second.id])
        #expect(first.title == "Email")
        #expect(store.activeSnippetID == first.id)
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func addIgnoresBlankText(_ text: String) {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()

        #expect(store.add(text: text) == nil)
        #expect(store.snippets.isEmpty)
    }

    @Test func deletingActiveSnippetReassignsActive() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        let first = try #require(store.add(text: "one"))
        let second = try #require(store.add(text: "two"))

        store.delete(first)
        #expect(store.activeSnippetID == second.id)

        store.delete(second)
        #expect(store.activeSnippetID == nil)
        #expect(store.snippets.isEmpty)
    }

    @Test func setActiveRejectsUnknownIDs() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        _ = try #require(store.add(text: "one"))
        let second = try #require(store.add(text: "two"))

        store.setActive(id: second.id)
        #expect(store.activeSnippet == second)

        store.setActive(id: UUID())
        #expect(store.activeSnippetID == second.id)

        store.setActive(id: nil)
        #expect(store.activeSnippet == nil)
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
        store.setActive(id: second.id)

        let reloaded = fixture.makeStore()

        #expect(reloaded.snippets == store.snippets)
        #expect(reloaded.activeSnippetID == second.id)
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

    @Test func copyActiveCopiesTheActiveSnippet() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let store = fixture.makeStore()
        #expect(store.copyActive() == false)

        _ = try #require(store.add(text: "first"))
        let second = try #require(store.add(text: "second"))
        store.setActive(id: second.id)

        #expect(store.copyActive())
        #expect(fixture.pasteboard.string(forType: .string) == "second")
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
