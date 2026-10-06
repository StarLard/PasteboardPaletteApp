//
//  SnippetEditorView.swift
//  Pasteboard Palette
//

import SwiftUI

/// A sheet for creating a new snippet or editing an existing one.
struct SnippetEditorView: View {
    enum Mode: Identifiable {
        case new
        case edit(Snippet)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let snippet): snippet.id.uuidString
            }
        }
    }

    let mode: Mode

    @Environment(SnippetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var text: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .new:
            _title = State(initialValue: "")
            _text = State(initialValue: "")
        case .edit(let snippet):
            _title = State(initialValue: snippet.title)
            _text = State(initialValue: snippet.text)
        }
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title, prompt: Text("e.g. Personal Email"))

                Section {
                    TextField("Text", text: $text, prompt: Text("Text to copy"), axis: .vertical)
                        .lineLimit(3...10)
                        .labelsHidden()
                } header: {
                    HStack {
                        Text("Text")
                        Spacer()
                        // PasteButton reads the pasteboard without triggering the
                        // system's paste-permission alert.
                        PasteButton(payloadType: String.self) { strings in
                            if let first = strings.first { text = first }
                        }
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "New Snippet" : "Edit Snippet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 280)
    }

    private var isNew: Bool {
        if case .new = mode { true } else { false }
    }

    private func save() {
        switch mode {
        case .new:
            store.add(title: title, text: text)
        case .edit(var snippet):
            snippet.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            snippet.text = text
            store.update(snippet)
        }
        dismiss()
    }
}

#Preview {
    SnippetEditorView(mode: .new)
        .environment(SnippetStore(defaults: UserDefaults(suiteName: "preview")!))
}
