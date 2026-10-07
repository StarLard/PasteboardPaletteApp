//
//  SnippetRow.swift
//  Pasteboard Palette
//

import SwiftData
import SwiftUI

/// A list row that copies its snippet when clicked and briefly shows a "Copied" badge.
struct SnippetRow: View {
    let snippet: Snippet
    /// Non-nil while this row's copy feedback should be visible.
    /// Changes on every copy so the badge re-animates on repeated clicks.
    let copyToken: UUID?
    let onCopy: () -> Void

    private var isShowingCopied: Bool { copyToken != nil }
    private var isPinned: Bool { snippet.isPinned }

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(snippet.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                trailingAccessory
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background {
                // Flash the row with the accent color when copied.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(isShowingCopied ? 0.15 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: copyToken)
        .accessibilityLabel(snippet.displayTitle)
        .accessibilityValue(isPinned ? Text("Pinned") : Text(""))
        .accessibilityHint("Copies the text to the pasteboard")
    }

    /// A tinted rounded-square icon, similar to the Passwords app.
    private var icon: some View {
        Image(systemName: "text.quote")
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color.accentColor.gradient, in: .rect(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isShowingCopied {
            Label("Copied", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.green.gradient, in: .capsule)
                .symbolEffect(.bounce, value: copyToken)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityHidden(true)
        } else if isPinned {
            Image(systemName: "pin.fill")
                .foregroundStyle(.orange)
                .help("Pinned")
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Snippet.sortIndex) var snippets: [Snippet]
    @Previewable @State var copyToken = UUID()
    VStack(spacing: 4) {
        ForEach(snippets) { snippet in
            // Show the "Work Email" row mid-copy to preview the "Copied" badge.
            SnippetRow(
                snippet: snippet,
                copyToken: snippet.title == "Work Email" ? copyToken : nil,
                onCopy: {}
            )
        }
    }
    .padding()
    .frame(width: 420)
}
