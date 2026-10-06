//
//  SettingsView.swift
//  Pasteboard Palette
//

import SwiftUI

/// Keys for values stored with `@AppStorage`.
enum AppStorageKey {
    static let showMenuBarExtra = "showMenuBarExtra"
}

/// The app's Settings window (Pasteboard Palette › Settings…).
struct SettingsView: View {
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @AppStorage(AppStorageKey.showMenuBarExtra) private var showMenuBarExtra = true

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.requiresApproval {
                    LabeledContent {
                        Button("Open Login Items…") { launchAtLogin.openLoginItemsSettings() }
                    } label: {
                        Text("Approval required")
                        Text("Allow Pasteboard Palette in System Settings › General › Login Items.")
                    }
                }
            }

            Section {
                Toggle("Show in menu bar", isOn: $showMenuBarExtra)
            } footer: {
                Text("Click the menu bar icon to copy any saved snippet. Your pinned snippet is always at the top.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { launchAtLogin.refresh() }
    }
}

#Preview {
    SettingsView()
        .environment(LaunchAtLogin())
}
