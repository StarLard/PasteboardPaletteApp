//
//  PasteboardPaletteApp.swift
//  Pasteboard Palette
//
//  Created by Caleb Friden on 10/6/26.
//

import SwiftData
import SwiftUI

/// The value presented by the main window group. There's only ever one, so
/// `openWindow(id:value:)` brings the existing window forward instead of
/// creating a duplicate.
enum MainWindow: String, Codable, Hashable {
    case main

    static let id = "main"
}

@main
struct PasteboardPaletteApp: App {
    @State private var modelContainer = ModelContainer.makeAppContainer()
    @State private var pasteboard = PasteboardController()
    @State private var launchAtLogin = LaunchAtLogin()
    @AppStorage(AppStorageKey.showMenuBarExtra) private var showMenuBarExtra = true

    var body: some Scene {
        // A WindowGroup (rather than a single `Window`) keeps the app — and the
        // menu bar extra — running after the window is closed.
        WindowGroup("Pasteboard Palette", id: MainWindow.id, for: MainWindow.self) { _ in
            ContentView()
                .environment(pasteboard)
        } defaultValue: {
            .main
        }
        // Both scenes share the container's main context, so an edit in one
        // shows up in the other immediately (not just after an autosave).
        .modelContext(modelContainer.mainContext)
        .defaultSize(width: 480, height: 520)
        .commands {
            SnippetCommands()
        }

        // Uses the `isInserted:` initializer so the extra coexists with the main
        // window, and so the user can hide it from Settings.
        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarContent()
                .environment(pasteboard)
                .environment(launchAtLogin)
        } label: {
            MenuBarLabel(pasteboard: pasteboard)
        }
        .menuBarExtraStyle(.menu)
        .modelContext(modelContainer.mainContext)

        Settings {
            SettingsView()
                .environment(launchAtLogin)
        }
    }
}

/// Adds File › New Snippet (⌘N) for the focused main window.
struct SnippetCommands: Commands {
    @FocusedValue(\.newSnippetAction) private var newSnippetAction

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Snippet") { newSnippetAction?() }
                .keyboardShortcut("n")
                .disabled(newSnippetAction == nil)
        }
    }
}
