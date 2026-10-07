//
//  Snippet.swift
//  Pasteboard Palette
//

import Foundation

/// A saved piece of text that can be copied to the pasteboard.
nonisolated struct Snippet: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    /// Optional, human-friendly name (e.g. "Personal Email").
    var title: String
    /// The text that gets copied to the pasteboard.
    var text: String
    var createdAt: Date
    /// When the snippet was last copied, or `nil` if it never has been.
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        title: String = "",
        text: String,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    /// Used to order recents. Snippets that were never copied count as used
    /// when they were created, so new snippets show up in recents right away.
    var recencyDate: Date {
        lastUsedAt ?? createdAt
    }

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
}
