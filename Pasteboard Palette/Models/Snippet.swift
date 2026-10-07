//
//  Snippet.swift
//  Pasteboard Palette
//

import Foundation
import SwiftData

/// A saved piece of text that can be copied to the pasteboard.
@Model
final class Snippet {
    /// Optional, human-friendly name (e.g. "Personal Email").
    var title: String = ""
    /// The text that gets copied to the pasteboard.
    var text: String = ""
    var createdAt: Date = Date.now
    /// When the title or text was last changed, or `nil` if never edited.
    var editedAt: Date?
    /// When the snippet was last copied, or `nil` if it never has been.
    var lastUsedAt: Date?
    /// Whether this is the (single) snippet pinned to the top of the list and menu bar.
    var isPinned: Bool = false
    /// Position in the main window's manually ordered list.
    var sortIndex: Int = 0

    init(
        title: String = "",
        text: String,
        createdAt: Date = .now,
        editedAt: Date? = nil,
        lastUsedAt: Date? = nil,
        isPinned: Bool = false,
        sortIndex: Int = 0
    ) {
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.sortIndex = sortIndex
    }
}

extension Snippet {
    /// How many recently used snippets the menu bar shows below the pinned one.
    static let menuBarRecentLimit = 3

    /// The title if one was given, otherwise the first non-empty line of the text.
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return firstLine ?? String(localized: "Untitled")
    }

    /// Used to order recents: when the snippet was last copied. Snippets that
    /// were never copied fall back to when they were last edited, then created,
    /// so new and freshly edited snippets show up in recents right away.
    var recencyDate: Date {
        lastUsedAt ?? editedAt ?? createdAt
    }

    /// Applies edits to the title and text, stamping `editedAt` if either changed.
    func update(title newTitle: String, text newText: String, now: Date = .now) {
        let newTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newTitle != title || newText != text else { return }
        title = newTitle
        text = newText
        editedAt = now
    }

    /// Display order for the main window: the pinned snippet first, then the
    /// rest in their manual order. Expects `snippets` sorted by `sortIndex`.
    static func pinnedFirst(_ snippets: [Snippet]) -> [Snippet] {
        guard let pinned = snippets.first(where: \.isPinned) else { return snippets }
        return [pinned] + snippets.filter { $0 !== pinned }
    }

    /// Unpinned snippets, most recently used first, limited to `limit`.
    /// Shown in the menu bar below the pinned snippet.
    static func recents(in snippets: [Snippet], limit: Int = menuBarRecentLimit) -> [Snippet] {
        Array(
            snippets
                .filter { !$0.isPinned }
                .sorted { $0.recencyDate > $1.recencyDate }
                .prefix(limit)
        )
    }
}
