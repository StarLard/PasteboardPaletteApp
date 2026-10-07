//
//  PasteboardController.swift
//  Pasteboard Palette
//

import AppKit
import Observation
import SwiftData

/// Copies snippets to the pasteboard and publishes copy feedback shared by the
/// main window (the "Copied" badge) and the menu bar icon (a checkmark).
@Observable
final class PasteboardController {
    /// Identifies the most recent copy. A fresh `token` is generated on every
    /// copy so repeated copies re-trigger animations.
    struct CopyFeedback: Equatable {
        let snippetID: PersistentIdentifier
        let token = UUID()
    }

    /// How long copy feedback stays visible.
    static let feedbackDuration: Duration = .seconds(1.2)

    private(set) var copyFeedback: CopyFeedback?

    @ObservationIgnored private let pasteboard: NSPasteboard
    /// Injectable clock so tests can control timestamps.
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    init(pasteboard: NSPasteboard = .general, now: @escaping () -> Date = { .now }) {
        self.pasteboard = pasteboard
        self.now = now
    }

    /// Writes the snippet's text to the pasteboard, records it as used, and
    /// publishes copy feedback.
    func copy(_ snippet: Snippet) {
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
        snippet.lastUsedAt = now()
        showFeedback(for: snippet.persistentModelID)
    }

    /// The current feedback token for `snippet`, or `nil` if its copy feedback
    /// isn't showing.
    func feedbackToken(for snippet: Snippet) -> UUID? {
        guard let copyFeedback, copyFeedback.snippetID == snippet.persistentModelID else { return nil }
        return copyFeedback.token
    }

    /// Reads plain text from the pasteboard.
    ///
    /// - Note: Programmatic pasteboard reads may show the system's paste
    ///   permission alert. Prefer `PasteButton` or `pasteDestination` in views.
    func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    private func showFeedback(for id: PersistentIdentifier) {
        feedbackTask?.cancel()
        let feedback = CopyFeedback(snippetID: id)
        copyFeedback = feedback
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: Self.feedbackDuration)
            guard !Task.isCancelled, self?.copyFeedback == feedback else { return }
            self?.copyFeedback = nil
        }
    }
}
