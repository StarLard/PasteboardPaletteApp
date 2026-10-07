//
//  SnippetAppearance.swift
//  Pasteboard Palette
//

import SwiftUI

/// The colors a snippet's icon can use. Stored by raw value, so never rename cases.
nonisolated enum SnippetColor: String, CaseIterable, Identifiable, Sendable {
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray

    static let `default` = SnippetColor.blue

    var id: Self { self }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }

    /// Spoken by VoiceOver in the color picker.
    var name: LocalizedStringResource {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .mint: "Mint"
        case .teal: "Teal"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .brown: "Brown"
        case .gray: "Gray"
        }
    }
}

/// The SF Symbols offered in the icon picker.
nonisolated enum SnippetSymbol {
    static let `default` = "text.quote"

    static let choices: [String] = [
        "text.quote", "envelope.fill", "at", "person.fill", "person.2.fill",
        "phone.fill", "message.fill", "house.fill", "building.2.fill", "mappin.and.ellipse",
        "briefcase.fill", "graduationcap.fill", "creditcard.fill", "cart.fill", "gift.fill",
        "link", "globe", "number", "calendar", "clock.fill",
        "doc.text.fill", "signature", "terminal.fill", "chevron.left.forwardslash.chevron.right", "hammer.fill",
        "star.fill", "heart.fill", "tag.fill", "bookmark.fill", "flag.fill",
        "lightbulb.fill", "bolt.fill", "leaf.fill", "airplane", "car.fill",
        "gamecontroller.fill", "music.note", "camera.fill", "pawprint.fill",
    ]
}

/// A snippet's icon: a white SF Symbol on a rounded square in the snippet's
/// color, similar to the Passwords app.
struct SnippetIconView: View {
    let symbolName: String
    let color: SnippetColor
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.color.gradient, in: .rect(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension SnippetIconView {
    init(snippet: Snippet, size: CGFloat = 32) {
        self.init(symbolName: snippet.iconName, color: snippet.color, size: size)
    }
}

extension Snippet {
    /// The snippet's icon rendered to a full-color image, for menus. Menu item
    /// images are otherwise drawn as monochrome templates, which would drop the color.
    @MainActor
    func menuIcon() -> Image {
        menuIconImage().map(Image.init(nsImage:)) ?? Image(systemName: iconName)
    }

    @MainActor
    func menuIconImage(size: CGFloat = 16) -> NSImage? {
        let renderer = ImageRenderer(content: SnippetIconView(snippet: self, size: size))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
