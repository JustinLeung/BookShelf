import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var viewModel = BookshelfViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BookshelfView(viewModel: viewModel)
                .tabItem {
                    Label("Bookshelf", systemImage: "books.vertical.fill")
                }
                .tag(0)

            ScannerView(viewModel: viewModel)
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .tag(1)

            ManualSearchView(viewModel: viewModel)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
    }
}

#if DEBUG
#Preview("With Books") {
    ContentView()
        .modelContainer(Book.previewContainer)
}

#Preview("Empty") {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
#endif
