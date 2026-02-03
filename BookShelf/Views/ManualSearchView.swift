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
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try a different search term")
                    }
                } else if viewModel.searchResults.isEmpty {
                    ContentUnavailableView {
                        Label("Search for Books", systemImage: "text.book.closed")
                    } description: {
                        Text("Enter an ISBN or search by title to find books")
                    }
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
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 70)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.gray)
                    }
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
            }
        }
        .padding(.vertical, 4)
    }
}
