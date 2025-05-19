import SwiftUI

/// A standard container for list-based views that provides consistent styling
struct StandardListContainer<Content: View>: View {
    let section: AppSection
    let content: Content
    let searchBinding: Binding<String>?
    let searchPrompt: String
    
    init(
        section: AppSection,
        searchBinding: Binding<String>? = nil,
        searchPrompt: String = "Search...",
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.searchBinding = searchBinding
        self.searchPrompt = searchPrompt
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                if let searchBinding = searchBinding {
                    // Search bar if provided
                    SearchBar(text: searchBinding, placeholder: searchPrompt)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                // Main content
                content
                    .background(Color.clear)
            }
        }
        .background(
            RadialGradient(
                gradient: AppTheme.mainGradient(for: section),
                center: .topTrailing,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
        )
    }
}

// Simpler version without search
extension StandardListContainer {
    init(
        section: AppSection,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            section: section,
            searchBinding: nil,
            content: content
        )
    }
}

// For preview
struct StandardListContainer_Previews: PreviewProvider {
    static var previews: some View {
        StandardListContainer(
            section: .dead,
            searchBinding: .constant(""),
            content: {
                List {
                    Text("Sample item 1")
                    Text("Sample item 2")
                    Text("Sample item 3")
                }
            }
        )
        .preferredColorScheme(.dark)
    }
} 