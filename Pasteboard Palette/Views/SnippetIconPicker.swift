//
//  SnippetIconPicker.swift
//  Pasteboard Palette
//

import SwiftUI

/// Lets the user choose a snippet's icon color and SF Symbol, similar to
/// choosing a list's appearance in Reminders.
struct SnippetIconPicker: View {
    @Binding var symbolName: String
    @Binding var color: SnippetColor

    private let swatchSize: CGFloat = 24
    private let symbolColumns = [GridItem(.adaptive(minimum: 32, maximum: 40), spacing: 8)]

    var body: some View {
        VStack(spacing: 16) {
            SnippetIconView(symbolName: symbolName, color: color, size: 56)
                .animation(.snappy, value: color)

            colorSwatches

            Divider()

            LazyVGrid(columns: symbolColumns, spacing: 8) {
                ForEach(SnippetSymbol.choices, id: \.self) { symbol in
                    symbolButton(symbol)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var colorSwatches: some View {
        HStack(spacing: 8) {
            ForEach(SnippetColor.allCases) { swatch in
                Button {
                    color = swatch
                } label: {
                    Circle()
                        .fill(swatch.color.gradient)
                        .frame(width: swatchSize, height: swatchSize)
                        .padding(3)
                        .overlay {
                            if swatch == color {
                                Circle().strokeBorder(.secondary, lineWidth: 2)
                            }
                        }
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(swatch.name))
                .accessibilityAddTraits(swatch == color ? .isSelected : [])
            }
        }
    }

    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = symbol == symbolName
        return Button {
            symbolName = symbol
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(isSelected ? AnyShapeStyle(color.color.gradient) : AnyShapeStyle(.quaternary))
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(symbol)
        .accessibilityLabel(Text(symbol.replacing(".fill", with: "").replacing(".", with: " ")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var symbolName = "envelope.fill"
    @Previewable @State var color = SnippetColor.blue
    SnippetIconPicker(symbolName: $symbolName, color: $color)
        .padding()
        .frame(width: 420)
}
