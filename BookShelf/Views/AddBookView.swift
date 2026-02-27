import SwiftUI
import VisionKit

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: BookshelfViewModel

    @State private var searchText = ""
    @State private var isShowingScanner = false
    @State private var isShowingCamera = false
    @State private var scannedISBN: String?
    @State private var showOCRResults = false
    @State private var ocrStatus: OCRStatus = .idle
    @State private var ocrSearchQuery: String?

    private var isTyping: Bool {
        !searchText.isEmpty
    }

    private var looksLikeISBN: Bool {
        let digits = searchText.filter { $0.isNumber }
        return !searchText.isEmpty && digits.count == searchText.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search by title or ISBN...", text: $searchText)
                        .textFieldStyle(.plain)
                        .keyboardType(looksLikeISBN ? .numberPad : .default)
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
                .background(AppTheme.Colors.cardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.smallCornerRadius))
                .padding(.horizontal)
                .padding(.top, 8)

                // Scan buttons — hidden once user starts typing
                if !isTyping {
                    scanButtons
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()
                    .padding(.top, 12)

                // Content area
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if !viewModel.searchResults.isEmpty {
                    searchResultsList
                } else if isTyping {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color.accentColor.opacity(0.08)))

                        Text("No Results")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Press Search or try a different term")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ocrStatusView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isTyping)
            .navigationTitle("Add Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.clearSearch()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                DataScannerRepresentable(scannedISBN: $scannedISBN)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraCaptureView { image in
                    processImageWithOCR(image)
                }
            }
            .sheet(isPresented: $showOCRResults) {
                OCRResultsSheet(viewModel: viewModel, searchQuery: ocrSearchQuery ?? "")
            }
            .onChange(of: scannedISBN) { _, newValue in
                if let isbn = newValue {
                    Task {
                        await viewModel.lookupBook(isbn: isbn)
                        scannedISBN = nil
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Scan Buttons

    private var scanButtons: some View {
        HStack(spacing: 12) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                Button {
                    isShowingScanner = true
                } label: {
                    Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Button {
                isShowingCamera = true
            } label: {
                Label("Photo of Cover", systemImage: "camera.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Search Results

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

    // MARK: - OCR Status

    @ViewBuilder
    private var ocrStatusView: some View {
        switch ocrStatus {
        case .idle:
            if viewModel.isLoading {
                Spacer()
                ProgressView("Looking up book...")
                Spacer()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Color.accentColor.opacity(0.08)))

                    Text("Search for Books")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Enter a title or ISBN, or scan a book to add it to your shelf")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .processing:
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Reading text from image...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        case .searching(let text):
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Searching for: \(text)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        case .found(let count):
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title)
                Text("Found \(count) result\(count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        case .error(let message):
            Spacer()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
            Spacer()
        }
    }

    // MARK: - Search Logic

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        Task {
            if looksLikeISBN {
                let cleanISBN = searchText.filter { $0.isNumber }
                await viewModel.lookupBook(isbn: cleanISBN)
            } else {
                await viewModel.searchBooks(query: searchText)
            }
        }
    }

    // MARK: - OCR Processing

    private func processImageWithOCR(_ image: UIImage) {
        ocrStatus = .processing

        Task {
            do {
                let recognizedText = try await OCRProcessor.performOCR(on: image)

                // First try to find an ISBN in the text
                if let isbn = OCRProcessor.extractISBN(from: recognizedText) {
                    ocrStatus = .searching(isbn)
                    await viewModel.lookupBook(isbn: isbn)
                    ocrStatus = .idle
                    return
                }

                // Apply OCR error corrections
                let correctedText = OCRProcessor.correctOCRErrors(recognizedText)

                // Extract title and author from OCR text
                let extracted = OCRProcessor.extractTitleAndAuthor(from: correctedText)

                // Also try to find potential author names for fallback search
                let potentialNames = OCRProcessor.findPotentialAuthorNames(from: correctedText)

                guard let title = extracted.title, !title.isEmpty else {
                    if !potentialNames.isEmpty {
                        let authorQuery = potentialNames.joined(separator: " ")
                        ocrStatus = .searching(authorQuery)
                        let fallbackResults = try await BookAPIService.shared.smartSearch(
                            query: authorQuery,
                            author: nil
                        )
                        if !fallbackResults.isEmpty {
                            viewModel.searchResults = fallbackResults
                            ocrSearchQuery = authorQuery
                            ocrStatus = .found(fallbackResults.count)
                            try? await Task.sleep(for: .seconds(0.5))
                            showOCRResults = true
                            ocrStatus = .idle
                            return
                        }
                    }

                    ocrStatus = .error("Could not find book information in the image")
                    try? await Task.sleep(for: .seconds(3))
                    ocrStatus = .idle
                    return
                }

                let displayQuery = extracted.author != nil ? "\(title) by \(extracted.author!)" : title
                ocrStatus = .searching(displayQuery)

                var results = try await BookAPIService.shared.smartSearch(
                    query: title,
                    author: extracted.author
                )

                if results.isEmpty && !potentialNames.isEmpty {
                    let authorQuery = potentialNames.joined(separator: " ")
                    ocrStatus = .searching(authorQuery)
                    results = try await BookAPIService.shared.smartSearch(
                        query: authorQuery,
                        author: nil
                    )
                }

                if results.isEmpty {
                    ocrStatus = .error("No books found. Try taking a clearer photo.")
                    try? await Task.sleep(for: .seconds(3))
                    ocrStatus = .idle
                } else {
                    viewModel.searchResults = results
                    ocrSearchQuery = displayQuery
                    ocrStatus = .found(results.count)
                    try? await Task.sleep(for: .seconds(0.5))
                    showOCRResults = true
                    ocrStatus = .idle
                }
            } catch {
                ocrStatus = .error("Search failed: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(3))
                ocrStatus = .idle
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
#Preview("Add Book - Empty") {
    AddBookView(viewModel: BookshelfViewModel())
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
