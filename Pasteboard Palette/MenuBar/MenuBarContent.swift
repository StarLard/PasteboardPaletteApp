//
//  MenuBarContent.swift
//  Pasteboard Palette
//

import SwiftData
import SwiftUI

/// The pull-down menu shown when clicking the menu bar icon.
struct MenuBarContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PasteboardController.self) private var pasteboard
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Snippet.sortIndex) private var snippets: [Snippet]

    private var pinned: Snippet? { snippets.first(where: \.isPinned) }

    var body: some View {
        if snippets.isEmpty {
            Text("No Snippets Yet")
        }

        // The pinned snippet stays at the top so copying it is a single click.
        if let pinned {
            Section("Pinned") {
                snippetButton(pinned)
                    .keyboardShortcut("c")
            }
        }

        // Then the most recently used snippets, newest first. Everything else
        // lives in the main window.
        let recents = Snippet.recents(in: snippets)
        if !recents.isEmpty {
            Section("Recent") {
                ForEach(recents) { snippet in
                    snippetButton(snippet)
                }
            }
        }

        Divider()

        if !snippets.isEmpty {
            Picker(selection: pinnedSelection) {
                Text("None").tag(PersistentIdentifier?.none)
                Divider()
                ForEach(Snippet.pinnedFirst(snippets)) { snippet in
                    Text(snippet.displayTitle).tag(Optional(snippet.persistentModelID))
                }
            } label: {
                Label("Pinned Snippet", systemImage: "pin")
            }
            .pickerStyle(.menu)
        }

        Button("Save Pasteboard as Snippet", systemImage: "plus.square.on.square") {
            if let string = pasteboard.readString() {
                modelContext.addSnippet(text: string)
            }
        }

        Divider()

        Button("Open Pasteboard Palette") {
            openWindow(id: MainWindow.id, value: MainWindow.main)
            NSApplication.shared.activate()
        }
        .keyboardShortcut("o")

        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        ))

        Divider()

        Button("Quit Pasteboard Palette") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// A menu item showing the snippet's colored icon, title, and text.
    private func snippetButton(_ snippet: Snippet) -> some View {
        Button {
            pasteboard.copy(snippet)
        } label: {
            Label {
                Text(snippet.displayTitle)
            } icon: {
                snippet.menuIcon()
            }
            Text(snippet.text)
        }
        .labelStyle(.titleAndIcon)
    }

    private var pinnedSelection: Binding<PersistentIdentifier?> {
        Binding(
            get: { pinned?.persistentModelID },
            set: { id in
                if let snippet = snippets.first(where: { $0.persistentModelID == id }) {
                    modelContext.pin(snippet)
                } else {
                    modelContext.unpinAll()
                }
            }
        )
    }
}

/// The menu bar icon. Briefly turns into a checkmark after a copy.
struct MenuBarLabel: View {
    let pasteboard: PasteboardController

    var body: some View {
        Image(systemName: pasteboard.copyFeedback == nil ? "list.clipboard" : "checkmark.circle")
            .accessibilityLabel("Pasteboard Palette")
    }
}
