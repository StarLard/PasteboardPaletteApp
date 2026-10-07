//
//  ModelContext+Snippets.swift
//  Pasteboard Palette
//

import Foundation
import SwiftData

/// Snippet operations that involve more than one model, such as keeping a
/// single pin or renumbering the manual order.
extension ModelContext {
    /// All snippets in their manual order.
    func allSnippets() -> [Snippet] {
        (try? fetch(FetchDescriptor<Snippet>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
    }

    /// Inserts a snippet at the end of the list. Returns `nil` (and adds
    /// nothing) if `text` is blank.
    @discardableResult
    func addSnippet(title: String = "", text: String, now: Date = .now) -> Snippet? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        var last = FetchDescriptor<Snippet>(sortBy: [SortDescriptor(\.sortIndex, order: .reverse)])
        last.fetchLimit = 1
        let nextIndex = ((try? fetch(last))?.first?.sortIndex ?? -1) + 1

        let snippet = Snippet(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            text: text,
            createdAt: now,
            sortIndex: nextIndex
        )
        insert(snippet)
        return snippet
    }

    /// Adds every non-blank string, e.g. the payload of a paste.
    func addSnippets(pasted strings: [String], now: Date = .now) {
        for string in strings { addSnippet(text: string, now: now) }
    }

    /// Pins a snippet, unpinning any other so only one is ever pinned.
    func pin(_ snippet: Snippet) {
        let pinned = (try? fetch(FetchDescriptor<Snippet>(predicate: #Predicate { $0.isPinned }))) ?? []
        for other in pinned where other !== snippet {
            other.isPinned = false
        }
        snippet.isPinned = true
    }

    func unpinAll() {
        let pinned = (try? fetch(FetchDescriptor<Snippet>(predicate: #Predicate { $0.isPinned }))) ?? []
        for snippet in pinned { snippet.isPinned = false }
    }

    /// Reorders snippets with `List.onMove` semantics. Offsets refer to the
    /// main window's display order (`Snippet.pinnedFirst`), and the pinned
    /// snippet always stays first.
    func moveSnippets(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = Snippet.pinnedFirst(allSnippets())
        let moving = source.map { ordered[$0] }
        let insertionIndex = destination - source.count(in: 0..<destination)
        for index in source.reversed() {
            ordered.remove(at: index)
        }
        ordered.insert(contentsOf: moving, at: insertionIndex)

        if let pinnedIndex = ordered.firstIndex(where: \.isPinned), pinnedIndex != 0 {
            ordered.insert(ordered.remove(at: pinnedIndex), at: 0)
        }

        for (index, snippet) in ordered.enumerated() where snippet.sortIndex != index {
            snippet.sortIndex = index
        }
    }
}

extension ModelContainer {
    /// The app's container. UI tests pass `--ui-testing` to get an empty,
    /// in-memory store instead of the user's real snippets.
    static func makeAppContainer() -> ModelContainer {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
        do {
            return try ModelContainer(for: Snippet.self, configurations: configuration)
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }
}
