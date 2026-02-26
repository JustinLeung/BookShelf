import SwiftUI

struct BookDetailView: View {
    let book: Book
    @Bindable var viewModel: BookshelfViewModel
    @Bindable var timerViewModel: ReadingTimerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showProgressUpdate = false
    @State private var showTimerView = false
    @State private var showNoteInput = false
    @State private var showQuoteScanner = false
    @State private var readingSessions: [ReadingProgressEntry] = []
    @State private var readingPace: Double?
    @State private var notes: [BookNote] = []

    enum DetailTab: String, CaseIterable {
        case activity = "Activity"
        case about = "About"
    }
    @State private var selectedTab: DetailTab

    init(book: Book, viewModel: BookshelfViewModel, timerViewModel: ReadingTimerViewModel, initialTab: DetailTab = .activity) {
        self.book = book
        self.viewModel = viewModel
        self.timerViewModel = timerViewModel
        self._selectedTab = State(initialValue: initialTab)
    }
    @State private var scrollOffset: CGFloat = 0

    private let maxCoverHeight: CGFloat = 200
    private let minCoverHeight: CGFloat = 60
    private let shrinkRange: CGFloat = 140

    private var coverHeight: CGFloat {
        let progress = min(max(scrollOffset / shrinkRange, 0), 1)
        return maxCoverHeight - (maxCoverHeight - minCoverHeight) * progress
    }

    private var headerCollapse: CGFloat {
        min(max(scrollOffset / shrinkRange, 0), 1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection

                Picker("Tab", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: -proxy.frame(in: .named("detailScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        switch selectedTab {
                        case .activity:
                            activityTabContent
                        case .about:
                            aboutTabContent
                        }
                    }
                }
                .coordinateSpace(name: "detailScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = value
                }
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        viewModel.deleteBook(book)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .task {
                loadSessions()
            }
            .sheet(isPresented: $showProgressUpdate) {
                ProgressUpdateView(
                    book: book,
                    previousPage: readingSessions.first?.page,
                    readingPace: readingPace
                ) { page, percentage in
                    viewModel.updateProgress(book, page: page, percentage: percentage)
                    loadSessions()
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: headerCollapse < 0.8 ? 12 : 8) {
            // Cover Image — shrinks as user scrolls
            BookCoverView(coverData: book.coverImageData, title: book.title, cornerRadius: 12)
                .frame(height: coverHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3 * (1 - headerCollapse)), radius: 8, x: 0, y: 4)

            // Title and Author — fade out as cover shrinks
            if headerCollapse < 1 {
                VStack(spacing: 8) {
                    Text(book.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(book.authorsDisplay)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(Double(1.0 - min(headerCollapse * 1.5, 1.0)))
            }

            // Status badge
            HStack(spacing: 6) {
                Image(systemName: book.readStatus.icon)
                    .font(.caption)
                Text(book.readStatus.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
            .sensoryFeedback(.impact(flexibility: .soft), trigger: book.readStatus)
            .animation(.easeInOut(duration: 0.2), value: book.readStatus)
        }
        .padding(.vertical, headerCollapse < 0.8 ? 16 : 8)
        .padding(.horizontal)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9), value: coverHeight)
    }

    // MARK: - Activity Tab

    private var activityTabContent: some View {
        VStack(spacing: 24) {
            actionButtonsSection

            switch book.readStatus {
            case .wantToRead:
                purchaseLinksSection
            case .currentlyReading:
                readingProgressSection
            case .read:
                ratingSection
                readingStatsSection
            case .paused:
                readingProgressSection
            case .didNotFinish:
                if let reason = book.dnfReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reason")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(reason)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                readingStatsSection
            }

            notesSection

            Spacer(minLength: 32)
        }
        .padding(.vertical)
    }

    // MARK: - Notes & Quotes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes & Quotes")
                    .font(.headline)
                Spacer()
                Menu {
                    Button {
                        showNoteInput = true
                    } label: {
                        Label("Add Note", systemImage: "note.text")
                    }
                    Button {
                        showQuoteScanner = true
                    } label: {
                        Label("Scan Quote", systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
            }

            if notes.isEmpty {
                Text("No notes or quotes yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes, id: \.dateCreated) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: note.noteType == .quote ? "quote.opening" : "note.text")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            Text(note.noteType == .quote ? "Quote" : "Note")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            if let page = note.pageNumber {
                                Text("p. \(page)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Text(note.text)
                            .font(.subheadline)
                            .lineLimit(4)
                            .italic(note.noteType == .quote)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteNote(note)
                            loadNotes()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showNoteInput) {
            NoteInputView(bookISBN: book.isbn, viewModel: viewModel)
        }
        .sheet(isPresented: $showQuoteScanner) {
            QuoteScannerView(bookISBN: book.isbn, viewModel: viewModel)
        }
        .onChange(of: showNoteInput) { _, isPresented in
            if !isPresented { loadNotes() }
        }
        .onChange(of: showQuoteScanner) { _, isPresented in
            if !isPresented { loadNotes() }
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            switch book.readStatus {
            case .wantToRead:
                statusButton(
                    title: "Start Reading",
                    icon: "play.fill",
                    prominent: true
                ) {
                    viewModel.setReadStatus(book, status: .currentlyReading)
                }
                statusButton(
                    title: "Mark as Read",
                    icon: "checkmark",
                    prominent: false
                ) {
                    viewModel.setReadStatus(book, status: .read)
                }
            case .currentlyReading:
                statusButton(
                    title: "Start Timer",
                    icon: "timer",
                    prominent: true
                ) {
                    timerViewModel.startSession(for: book)
                    showTimerView = true
                }
                statusButton(
                    title: "Quick Update",
                    icon: "chart.line.uptrend.xyaxis",
                    prominent: false
                ) {
                    showProgressUpdate = true
                }
                HStack(spacing: 12) {
                    Button {
                        viewModel.setReadStatus(book, status: .read)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Finished")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Button {
                        viewModel.setReadStatus(book, status: .paused)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pause")
                            Text("Pause")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            case .read:
                statusButton(
                    title: "Read Again",
                    icon: "play.fill",
                    prominent: false
                ) {
                    viewModel.setReadStatus(book, status: .currentlyReading)
                }
            case .paused:
                statusButton(
                    title: "Resume Reading",
                    icon: "play.fill",
                    prominent: true
                ) {
                    viewModel.setReadStatus(book, status: .currentlyReading)
                }
                statusButton(
                    title: "Mark as Did Not Finish",
                    icon: "xmark",
                    prominent: false
                ) {
                    viewModel.setReadStatus(book, status: .didNotFinish)
                }
            case .didNotFinish:
                statusButton(
                    title: "Start Over",
                    icon: "arrow.counterclockwise",
                    prominent: true
                ) {
                    viewModel.setReadStatus(book, status: .wantToRead)
                }
                statusButton(
                    title: "Resume Reading",
                    icon: "play.fill",
                    prominent: false
                ) {
                    viewModel.setReadStatus(book, status: .currentlyReading)
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showTimerView) {
            ReadingTimerView(timerViewModel: timerViewModel, viewModel: viewModel)
        }
    }

    private var readingProgressSection: some View {
        VStack(spacing: 16) {
            // Compact ring + stats side-by-side
            if let progress = book.calculatedProgress {
                HStack(spacing: 20) {
                    CircularProgressRing(
                        progress: progress,
                        size: 80,
                        lineWidth: 6,
                        showPercentage: true
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        if let page = book.currentPage, let total = book.pageCount {
                            Text("Page \(page) of \(total)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let pace = readingPace {
                            Text("~\(Int(pace)) pages/day")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let pace = readingPace,
                           let current = book.currentPage,
                           let total = book.pageCount,
                           pace > 0 {
                            let remaining = total - current
                            let daysLeft = Int(ceil(Double(remaining) / pace))
                            Text("~\(daysLeft) days left")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            // Recent sessions
            if !readingSessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sessions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(Array(readingSessions.prefix(5).enumerated()), id: \.offset) { index, session in
                        HStack {
                            Text(session.timestamp.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let page = session.page {
                                Text("p. \(page)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }

                            let nextSession = index + 1 < readingSessions.count ? readingSessions[index + 1] : nil
                            if let pagesRead = session.pagesRead(since: nextSession) {
                                Text("+\(pagesRead)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor, in: Capsule())
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }

    private var purchaseLinksSection: some View {
        HStack(spacing: 16) {
            if let amazonURL = book.amazonURL {
                Link(destination: amazonURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "cart")
                            .font(.subheadline)
                        Text("Amazon")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
                }
            }

            if let audibleURL = book.audibleURL {
                Link(destination: audibleURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "headphones")
                            .font(.subheadline)
                        Text("Audible")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
    }

    private var ratingSection: some View {
        VStack(spacing: 4) {
            Text("Your Rating")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            StarRatingView(
                rating: book.rating,
                interactive: true,
                starSize: 32
            ) { newRating in
                viewModel.setRating(book, rating: newRating)
            }
        }
    }

    private var readingStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            let hasStats = book.dateStarted != nil || book.dateFinished != nil || book.daysToRead != nil
            if hasStats {
                DetailSection(title: "Reading Stats") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let dateStarted = book.dateStarted {
                            DetailRow(label: "Started", value: dateStarted.formatted(date: .abbreviated, time: .omitted))
                        }

                        if let dateFinished = book.dateFinished {
                            DetailRow(label: "Finished", value: dateFinished.formatted(date: .abbreviated, time: .omitted))
                        }

                        if let days = book.daysToRead {
                            DetailRow(label: "Days to Read", value: "\(days) days")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - About Tab

    private var aboutTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let description = book.bookDescription {
                DetailSection(title: "Description") {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            DetailSection(title: "Details") {
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "ISBN", value: book.isbn)

                    if let publisher = book.publisher {
                        DetailRow(label: "Publisher", value: publisher)
                    }

                    if let publishDate = book.publishDate {
                        DetailRow(label: "Published", value: publishDate)
                    }

                    if let pageCount = book.pageCount {
                        DetailRow(label: "Pages", value: "\(pageCount)")
                    }

                    if let _ = book.rating {
                        DetailRow(label: "Rating", value: book.ratingDisplay)
                    }

                    if let dateStarted = book.dateStarted {
                        DetailRow(label: "Started", value: dateStarted.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let dateFinished = book.dateFinished {
                        DetailRow(label: "Finished", value: dateFinished.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let days = book.daysToRead {
                        DetailRow(label: "Days to Read", value: "\(days) days")
                    }

                    DetailRow(label: "Added", value: book.dateAdded.formatted(date: .abbreviated, time: .omitted))
                }
            }

            Spacer(minLength: 32)
        }
        .padding()
    }

    // MARK: - Helpers

    private func statusButton(title: String, icon: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(prominent ? Color.accentColor : Color.accentColor.opacity(0.12))
            .foregroundStyle(prominent ? .white : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func loadSessions() {
        readingSessions = viewModel.fetchReadingSessions(for: book.isbn)
        readingPace = viewModel.readingPace(for: book.isbn)
        loadNotes()
    }

    private func loadNotes() {
        notes = viewModel.fetchNotes(for: book.isbn)
    }
}

// MARK: - Preference Keys

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Helper Views

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 18)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Want to Read") {
    BookDetailView(book: .sampleWantToRead, viewModel: BookshelfViewModel(), timerViewModel: ReadingTimerViewModel())
}

#Preview("Currently Reading") {
    BookDetailView(book: .sampleCurrentlyReading, viewModel: BookshelfViewModel(), timerViewModel: ReadingTimerViewModel())
}

#Preview("Read with Rating") {
    BookDetailView(book: .sampleReadWithRating, viewModel: BookshelfViewModel(), timerViewModel: ReadingTimerViewModel())
}

#Preview("Read without Rating") {
    BookDetailView(book: .sampleReadNoRating, viewModel: BookshelfViewModel(), timerViewModel: ReadingTimerViewModel())
}

#Preview("Detail Section") {
    DetailSection(title: "Description") {
        Text("A sample description of a book that spans multiple lines to show how the section looks with longer content.")
    }
    .padding()
}

#Preview("Detail Row") {
    DetailRow(label: "Publisher", value: "Harper Perennial")
        .padding()
}
#endif
