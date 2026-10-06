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

    private(set) var snippets: [Snippet] = []
    private(set) var activeSnippetID: UUID?
    private(set) var copyFeedback: CopyFeedback?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    enum DefaultsKey {
        static let snippets = "snippets"
        static let activeSnippetID = "activeSnippetID"
    }

    init(defaults: UserDefaults = .standard, pasteboard: NSPasteboard = .general) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        load()
    }

    // MARK: - Queries

    /// The snippet copied from the menu bar extra.
    var activeSnippet: Snippet? {
        guard let activeSnippetID else { return nil }
        return snippets.first { $0.id == activeSnippetID }
    }

    // MARK: - Editing

    /// Adds a snippet. Returns `nil` (and adds nothing) if `text` is blank.
    /// The first snippet ever added automatically becomes the active one.
    @discardableResult
    func add(title: String = "", text: String) -> Snippet? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let snippet = Snippet(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            text: text
        )
        snippets.append(snippet)
        if activeSnippet == nil { activeSnippetID = snippet.id }
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

    /// Deletes a snippet. If it was active, the first remaining snippet becomes active.
    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        if activeSnippetID == snippet.id {
            activeSnippetID = snippets.first?.id
        }
        save()
    }

    /// Reorders snippets with `List.onMove` semantics: `destination` is an index
    /// in the array *before* the move.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { snippets[$0] }
        let insertionIndex = destination - source.count(in: 0..<destination)
        for index in source.reversed() {
            snippets.remove(at: index)
        }
        snippets.insert(contentsOf: moving, at: insertionIndex)
        save()
    }

    /// Chooses which snippet the menu bar extra copies.
    func setActive(id: UUID?) {
        guard id == nil || snippets.contains(where: { $0.id == id }) else { return }
        activeSnippetID = id
        save()
    }

    // MARK: - Copying

    /// Writes the snippet's text to the pasteboard and publishes copy feedback.
    func copy(_ snippet: Snippet) {
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
        showFeedback(for: snippet.id)
    }

    /// Copies the active snippet. Returns `false` if there isn't one.
    @discardableResult
    func copyActive() -> Bool {
        guard let activeSnippet else { return false }
        copy(activeSnippet)
        return true
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
        if let idString = defaults.string(forKey: DefaultsKey.activeSnippetID),
           let id = UUID(uuidString: idString),
           snippets.contains(where: { $0.id == id }) {
            activeSnippetID = id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            defaults.set(data, forKey: DefaultsKey.snippets)
        }
        defaults.set(activeSnippetID?.uuidString, forKey: DefaultsKey.activeSnippetID)
    }
}
