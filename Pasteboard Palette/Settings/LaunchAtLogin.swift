//
//  LaunchAtLogin.swift
//  Pasteboard Palette
//

import Observation
import OSLog
import ServiceManagement

/// Registers the app as a login item using `SMAppService`.
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = false
    /// `true` when the user must approve the login item in System Settings.
    private(set) var requiresApproval = false

    @ObservationIgnored private let service = SMAppService.mainApp
    @ObservationIgnored private let logger = Logger(subsystem: "PasteboardPalette", category: "LaunchAtLogin")

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            logger.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)")
        }
        refresh()
    }

    /// Re-reads the status, which the user can change in System Settings at any time.
    func refresh() {
        isEnabled = service.status == .enabled
        requiresApproval = service.status == .requiresApproval
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
