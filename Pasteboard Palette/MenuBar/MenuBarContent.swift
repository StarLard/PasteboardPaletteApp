//
//  MenuBarContent.swift
//  Pasteboard Palette
//

import SwiftUI

/// The pull-down menu shown when clicking the menu bar icon.
struct MenuBarContent: View {
    @Environment(SnippetStore.self) private var store
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.snippets.isEmpty {
            Text("No Snippets Yet")
        }

        // The pinned snippet stays at the top so copying it is a single click.
        if let pinned = store.pinnedSnippet {
            Button {
                store.copy(pinned)
            } label: {
                Label(pinned.displayTitle, systemImage: "pin.fill")
                Text(pinned.text)
            }
            .labelStyle(.titleAndIcon)
            .keyboardShortcut("c")
        }

        // Then the most recently used snippets, newest first. Everything else
        // lives in the main window.
        let recents = store.recentSnippets()
        if !recents.isEmpty {
            Section("Recent") {
                ForEach(recents) { snippet in
                    Button {
                        store.copy(snippet)
                    } label: {
                        Text(snippet.displayTitle)
                        Text(snippet.text)
                    }
                }
            }
        }

        Divider()

        if !store.snippets.isEmpty {
            Picker(selection: Binding(
                get: { store.pinnedSnippetID },
                set: { store.setPinned(id: $0) }
            )) {
                Text("None").tag(UUID?.none)
                Divider()
                ForEach(store.orderedSnippets) { snippet in
                    Text(snippet.displayTitle).tag(Optional(snippet.id))
                }
            } label: {
                Label("Pinned Snippet", systemImage: "pin")
            }
            .pickerStyle(.menu)
        }

        Button("Save Pasteboard as Snippet", systemImage: "plus.square.on.square") {
            store.addFromPasteboard()
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
}

/// The menu bar icon. Briefly turns into a checkmark after a copy.
struct MenuBarLabel: View {
    let store: SnippetStore

    var body: some View {
        Image(systemName: store.copyFeedback == nil ? "list.clipboard" : "checkmark.circle")
            .accessibilityLabel("Pasteboard Palette")
    }
}
