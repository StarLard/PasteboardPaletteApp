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
        if let active = store.activeSnippet {
            // The menu bar snippet comes first so copying it is a single click.
            Button {
                store.copy(active)
            } label: {
                Label("Copy \u{201C}\(active.displayTitle)\u{201D}", systemImage: "doc.on.doc")
                Text(active.text)
            }
            .keyboardShortcut("c")
        } else if store.snippets.isEmpty {
            Text("No Snippets Yet")
        } else {
            Text("No Menu Bar Snippet Chosen")
        }

        let others = store.snippets.filter { $0.id != store.activeSnippetID }
        if !others.isEmpty {
            Section("Other Snippets") {
                ForEach(others) { snippet in
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
            Picker("Menu Bar Snippet", selection: Binding(
                get: { store.activeSnippetID },
                set: { store.setActive(id: $0) }
            )) {
                ForEach(store.snippets) { snippet in
                    Text(snippet.displayTitle).tag(Optional(snippet.id))
                }
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
