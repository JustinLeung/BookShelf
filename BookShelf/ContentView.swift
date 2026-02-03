import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
