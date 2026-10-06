//
//  SnippetStore.swift
//  Pasteboard Palette
//

import AppKit
import Observation

/// The single source of truth for saved snippets, shared by the main window
/// and the menu bar extra. Persists to `UserDefaults`.
@Observable
final class SnippetStore {
    /// Identifies the most recent copy so the UI can show feedback.
    /// A fresh `token` is generated on every copy so repeated copies re-trigger animations.
    struct CopyFeedback: Equatable {
        let snippetID: UUID
        let token = UUID()
    }

    /// How long copy feedback (row badge, menu bar checkmark) stays visible.
    static let feedbackDuration: Duration = .seconds(1.2)

    /// Snippets in their saved order. Use `orderedSnippets` for display.
    private(set) var snippets: [Snippet] = []
    /// The one snippet pinned to the top of the app's list and the menu bar menu.
    private(set) var pinnedSnippetID: UUID?
    private(set) var copyFeedback: CopyFeedback?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    enum DefaultsKey {
        static let snippets = "snippets"
        static let pinnedSnippetID = "pinnedSnippetID"
    }

    init(defaults: UserDefaults = .standard, pasteboard: NSPasteboard = .general) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        load()
    }

    // MARK: - Queries

    var pinnedSnippet: Snippet? {
        guard let pinnedSnippetID else { return nil }
        return snippets.first { $0.id == pinnedSnippetID }
    }

    /// Snippets in display order: the pinned snippet first, then the rest.
    var orderedSnippets: [Snippet] {
        guard let pinnedSnippet else { return snippets }
        return [pinnedSnippet] + snippets.filter { $0.id != pinnedSnippet.id }
    }

    func isPinned(_ snippet: Snippet) -> Bool {
        snippet.id == pinnedSnippetID
    }

    // MARK: - Editing

    /// Adds a snippet. Returns `nil` (and adds nothing) if `text` is blank.
    @discardableResult
    func add(title: String = "", text: String) -> Snippet? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let snippet = Snippet(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            text: text
        )
        snippets.append(snippet)
        save()
        return snippet
    }

    /// Adds every non-blank string, e.g. the payload of a paste.
    func add(pasted strings: [String]) {
        for string in strings { add(text: string) }
    }

    /// Reads plain text from the pasteboard and saves it as a new snippet.
    ///
    /// - Note: Programmatic pasteboard reads may show the system's paste
    ///   permission alert. Prefer `PasteButton` or `pasteDestination` in views.
    @discardableResult
    func addFromPasteboard() -> Snippet? {
        guard let string = pasteboard.string(forType: .string) else { return nil }
        return add(text: string)
    }

    func update(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        save()
    }

    /// Deletes a snippet, unpinning it first if needed.
    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        if pinnedSnippetID == snippet.id {
            pinnedSnippetID = nil
        }
        save()
    }

    /// Reorders snippets with `List.onMove` semantics. Offsets refer to
    /// `orderedSnippets` (the display order), and `destination` is an index
    /// *before* the move. The pinned snippet always stays first.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = orderedSnippets
        let moving = source.map { ordered[$0] }
        let insertionIndex = destination - source.count(in: 0..<destination)
        for index in source.reversed() {
            ordered.remove(at: index)
        }
        ordered.insert(contentsOf: moving, at: insertionIndex)

        if let pinnedSnippetID,
           let pinnedIndex = ordered.firstIndex(where: { $0.id == pinnedSnippetID }),
           pinnedIndex != 0 {
            ordered.insert(ordered.remove(at: pinnedIndex), at: 0)
        }

        snippets = ordered
        save()
    }

    /// Pins a snippet to the top, replacing any previously pinned snippet.
    func pin(_ snippet: Snippet) {
        setPinned(id: snippet.id)
    }

    func unpin() {
        setPinned(id: nil)
    }

    /// Pins the snippet with `id`, or unpins when `nil`. Unknown IDs are ignored.
    func setPinned(id: UUID?) {
        guard id == nil || snippets.contains(where: { $0.id == id }) else { return }
        pinnedSnippetID = id
        save()
    }

    // MARK: - Copying

    /// Writes the snippet's text to the pasteboard and publishes copy feedback.
    func copy(_ snippet: Snippet) {
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
        showFeedback(for: snippet.id)
    }

    private func showFeedback(for id: UUID) {
        feedbackTask?.cancel()
        let feedback = CopyFeedback(snippetID: id)
        copyFeedback = feedback
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: Self.feedbackDuration)
            guard !Task.isCancelled, self?.copyFeedback == feedback else { return }
            self?.copyFeedback = nil
        }
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: DefaultsKey.snippets),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
        }
        if let idString = defaults.string(forKey: DefaultsKey.pinnedSnippetID),
           let id = UUID(uuidString: idString),
           snippets.contains(where: { $0.id == id }) {
            pinnedSnippetID = id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            defaults.set(data, forKey: DefaultsKey.snippets)
        }
        defaults.set(pinnedSnippetID?.uuidString, forKey: DefaultsKey.pinnedSnippetID)
    }
}
