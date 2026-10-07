//
//  SampleData.swift
//  Pasteboard Palette
//

#if DEBUG
import SwiftData
import SwiftUI

/// An in-memory container with a few snippets, for SwiftUI previews.
struct SampleData: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Snippet.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        if let email = context.addSnippet(title: "Personal Email", text: "me@example.com", iconName: "envelope.fill", color: .blue) {
            context.pin(email)
        }
        context.addSnippet(title: "Work Email", text: "me@work.example.com", iconName: "briefcase.fill", color: .orange)
        context.addSnippet(text: "123 Main Street\nSpringfield", iconName: "house.fill", color: .green)
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content
            .modelContainer(context)
            .environment(PasteboardController(pasteboard: .withUniqueName()))
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleData: Self = .modifier(SampleData())
}
#endif
