//
//  ContentView.swift
//  Pasteboard Palette
//

import SwiftData
import SwiftUI

/// The main window: a searchable list of snippets. Click a row to copy it.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PasteboardController.self) private var pasteboard
    @Query(sort: \Snippet.sortIndex) private var snippets: [Snippet]

    @State private var searchText = ""
    @State private var editorMode: SnippetEditorView.Mode?

    /// Snippets in display order (pinned first), filtered by the search text.
    private var filteredSnippets: [Snippet] {
        let ordered = Snippet.pinnedFirst(snippets)
        guard !searchText.isEmpty else { return ordered }
        return ordered.filter {
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
                            modelContext.addSnippets(pasted: strings)
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
            modelContext.addSnippets(pasted: strings)
        }
        .sheet(item: $editorMode) { mode in
            SnippetEditorView(mode: mode)
        }
        .focusedSceneValue(\.newSnippetAction, NewSnippetAction { editorMode = .new })
        .frame(minWidth: 360, minHeight: 300)
    }

    @ViewBuilder
    private var content: some View {
        if snippets.isEmpty {
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
                    copyToken: pasteboard.feedbackToken(for: snippet),
                    onCopy: { copy(snippet) }
                )
                .contextMenu { contextMenu(for: snippet) }
                // The pinned snippet always stays at the top.
                .moveDisabled(snippet.isPinned)
            }
            .onMove(perform: moveAction)
        }
        .listStyle(.inset)
    }

    /// Reordering is only meaningful when the full, unfiltered list is visible.
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard searchText.isEmpty else { return nil }
        return { source, destination in
            modelContext.moveSnippets(fromOffsets: source, toOffset: destination)
        }
    }

    @ViewBuilder
    private func contextMenu(for snippet: Snippet) -> some View {
        Button("Copy", systemImage: "doc.on.doc") { copy(snippet) }

        if snippet.isPinned {
            Button("Unpin", systemImage: "pin.slash") {
                withAnimation { snippet.isPinned = false }
            }
        } else {
            Button("Pin", systemImage: "pin") {
                withAnimation { modelContext.pin(snippet) }
            }
        }

        Divider()

        Button("Edit…", systemImage: "pencil") { editorMode = .edit(snippet) }
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation { modelContext.delete(snippet) }
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
                modelContext.addSnippets(pasted: strings)
            }
        }
    }

    private func copy(_ snippet: Snippet) {
        pasteboard.copy(snippet)
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

// SampleData is debug-only, so previews that use it are too.
#if DEBUG
#Preview("With Snippets", traits: .sampleData) {
    ContentView()
        .frame(width: 480, height: 400)
}
#endif

#Preview("Empty") {
    ContentView()
        .modelContainer(for: Snippet.self, inMemory: true)
        .environment(PasteboardController(pasteboard: .withUniqueName()))
        .frame(width: 480, height: 400)
}
