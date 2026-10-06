//
//  ContentView.swift
//  Pasteboard Palette
//

import SwiftUI

/// The main window: a searchable list of snippets. Click a row to copy it.
struct ContentView: View {
    @Environment(SnippetStore.self) private var store
    @State private var searchText = ""
    @State private var editorMode: SnippetEditorView.Mode?

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return store.snippets }
        return store.snippets.filter {
            $0.displayTitle.localizedStandardContains(searchText)
                || $0.text.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pasteboard Palette")
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search Snippets")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        PasteButton(payloadType: String.self) { strings in
                            store.add(pasted: strings)
                        }
                        .help("Save the text on the pasteboard as a new snippet")

                        Button("New Snippet", systemImage: "plus") {
                            editorMode = .new
                        }
                        .help("Type a new snippet")
                    }
                }
        }
        // ⌘V / Edit › Paste saves the pasteboard text as a new snippet.
        .pasteDestination(for: String.self) { strings in
            store.add(pasted: strings)
        }
        .sheet(item: $editorMode) { mode in
            SnippetEditorView(mode: mode)
        }
        .focusedSceneValue(\.newSnippetAction, NewSnippetAction { editorMode = .new })
        .frame(minWidth: 360, minHeight: 300)
    }

    @ViewBuilder
    private var content: some View {
        if store.snippets.isEmpty {
            emptyState
        } else if filteredSnippets.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(filteredSnippets) { snippet in
                SnippetRow(
                    snippet: snippet,
                    isActive: snippet.id == store.activeSnippetID,
                    copyToken: store.copyFeedback?.snippetID == snippet.id
                        ? store.copyFeedback?.token : nil,
                    onCopy: { copy(snippet) }
                )
                .contextMenu { contextMenu(for: snippet) }
            }
            .onMove(perform: moveAction)
        }
        .listStyle(.inset)
    }

    /// Reordering is only meaningful when the full, unfiltered list is visible.
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard searchText.isEmpty else { return nil }
        return { source, destination in
            store.move(fromOffsets: source, toOffset: destination)
        }
    }

    @ViewBuilder
    private func contextMenu(for snippet: Snippet) -> some View {
        Button("Copy", systemImage: "doc.on.doc") { copy(snippet) }

        if snippet.id == store.activeSnippetID {
            Button("Remove from Menu Bar", systemImage: "menubar.rectangle") {
                store.setActive(id: nil)
            }
        } else {
            Button("Use in Menu Bar", systemImage: "menubar.rectangle") {
                store.setActive(id: snippet.id)
            }
        }

        Divider()

        Button("Edit…", systemImage: "pencil") { editorMode = .edit(snippet) }
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation { store.delete(snippet) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Snippets", systemImage: "list.clipboard")
        } description: {
            Text("Save text you copy often, like your email address, then click it to copy it again.")
        } actions: {
            Button("New Snippet") { editorMode = .new }
            PasteButton(payloadType: String.self) { strings in
                store.add(pasted: strings)
            }
        }
    }

    private func copy(_ snippet: Snippet) {
        store.copy(snippet)
        AccessibilityNotification.Announcement("Copied \(snippet.displayTitle)").post()
    }
}

/// Opens the new-snippet editor in the focused window.
struct NewSnippetAction: Equatable {
    let perform: () -> Void

    func callAsFunction() { perform() }

    /// The closure only writes to the window's `@State`, whose storage is stable,
    /// so any two instances are interchangeable. This avoids needless invalidation.
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension FocusedValues {
    /// Lets the File › New Snippet command open the editor in the focused window.
    @Entry var newSnippetAction: NewSnippetAction?
}

#Preview("With Snippets") {
    let store = SnippetStore(defaults: UserDefaults(suiteName: "preview-content")!)
    if store.snippets.isEmpty {
        store.add(title: "Personal Email", text: "me@example.com")
        store.add(title: "Work Email", text: "me@work.example.com")
        store.add(text: "123 Main Street\nSpringfield")
    }
    return ContentView()
        .environment(store)
        .frame(width: 480, height: 400)
}

#Preview("Empty") {
    ContentView()
        .environment(SnippetStore(defaults: UserDefaults(suiteName: "preview-empty-\(UUID())")!))
        .frame(width: 480, height: 400)
}
