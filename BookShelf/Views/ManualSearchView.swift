import SwiftUI

struct ManualSearchView: View {
    @Bindable var viewModel: BookshelfViewModel

    @State private var searchText = ""
    @State private var searchMode: SearchMode = .isbn

    enum SearchMode: String, CaseIterable {
        case isbn = "ISBN"
        case title = "Title"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                VStack(spacing: 12) {
                    Picker("Search Mode", selection: $searchMode) {
                        ForEach(SearchMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField(searchMode == .isbn ? "Enter ISBN..." : "Search by title...", text: $searchText)
                            .textFieldStyle(.plain)
                            .keyboardType(searchMode == .isbn ? .numberPad : .default)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                performSearch()
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                viewModel.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()

                Divider()

                // Results
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color.accentColor.opacity(0.08)))

                        Text("No Results")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.searchResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color.accentColor.opacity(0.08)))

                        Text("Search for Books")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Enter an ISBN or search by title to find books")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private var searchResultsList: some View {
        List(viewModel.searchResults) { result in
            SearchResultRow(result: result, isInShelf: viewModel.isBookInShelf(isbn: result.isbn)) {
                Task {
                    await viewModel.addBookFromResult(result)
                }
            }
        }
        .listStyle(.plain)
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        Task {
            if searchMode == .isbn {
                let cleanISBN = searchText.filter { $0.isNumber }
                await viewModel.lookupBook(isbn: cleanISBN)
            } else {
                await viewModel.searchBooks(query: searchText)
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: BookSearchResult
    let isInShelf: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Cover thumbnail
            if let coverURL = result.coverURL {
                CachedAsyncImage(isbn: result.isbn, coverURL: coverURL)
                    .frame(width: 50, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
            } else {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 70)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 2, height: 70)

                    Image(systemName: "book.closed")
                        .foregroundStyle(Color.accentColor.opacity(0.5))
                        .frame(width: 50, height: 70)
                }
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
            }

            // Book info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                if !result.authors.isEmpty {
                    Text(result.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let year = result.publishDate {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Add button
            if isInShelf {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: isInShelf)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Search - Empty") {
    ManualSearchView(viewModel: BookshelfViewModel())
}

#Preview("Search Result Row") {
    SearchResultRow(
        result: BookSearchResult.sampleResults[0],
        isInShelf: false
    ) {}
    .padding()
}

#Preview("Search Result Row - In Shelf") {
    SearchResultRow(
        result: BookSearchResult.sampleResults[0],
        isInShelf: true
    ) {}
    .padding()
}
#endif
