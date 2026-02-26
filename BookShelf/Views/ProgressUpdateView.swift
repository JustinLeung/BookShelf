import SwiftUI

struct ProgressUpdateView: View {
    let book: Book
    let previousPage: Int?
    let readingPace: Double?
    let onSave: (Int?, Double?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pageText: String = ""
    @State private var sliderValue: Double = 0.0
    @State private var showSessionBadge = false

    private var hasPageCount: Bool {
        book.pageCount != nil && book.pageCount! > 0
    }

    private var enteredPage: Int? {
        Int(pageText)
    }

    private var liveProgress: Double {
        if hasPageCount, let page = enteredPage, let total = book.pageCount {
            return min(1.0, max(0.0, Double(page) / Double(total)))
        }
        return sliderValue
    }

    private var pagesReadThisSession: Int? {
        guard let current = enteredPage, let previous = previousPage else { return nil }
        let diff = current - previous
        return diff > 0 ? diff : nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(book.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top)

                // Hero progress ring
                CircularProgressRing(
                    progress: liveProgress,
                    size: 160,
                    lineWidth: 12,
                    showPercentage: true
                )

                if hasPageCount {
                    pageInputSection
                } else {
                    percentageSliderSection
                }

                // Session stats badge
                if let pagesRead = pagesReadThisSession {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text("You read \(pagesRead) pages!")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                }

                // Reading pace
                if let pace = readingPace {
                    Text("~\(Int(pace)) pages/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if hasPageCount {
                        let page = enteredPage.map { max(0, min($0, book.pageCount ?? $0)) }
                        onSave(page, nil)
                    } else {
                        onSave(nil, sliderValue)
                    }
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let currentPage = book.currentPage {
                    pageText = "\(currentPage)"
                }
                if let progress = book.progressPercentage {
                    sliderValue = progress
                }
            }
            .animation(.easeOut, value: pagesReadThisSession)
        }
    }

    private var pageInputSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Page")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("0", text: $pageText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 140)

                if let total = book.pageCount {
                    Text("of \(total)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Quick-increment buttons
            HStack(spacing: 12) {
                ForEach([5, 10, 25], id: \.self) { increment in
                    Button {
                        let current = enteredPage ?? book.currentPage ?? 0
                        let newPage = min(current + increment, book.pageCount ?? Int.max)
                        pageText = "\(newPage)"
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Text("+\(increment)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var percentageSliderSection: some View {
        VStack(spacing: 16) {
            Slider(value: $sliderValue, in: 0...1, step: 0.01)
                .padding(.horizontal, 40)

            Text("No page count available — set progress manually")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview("With Page Count") {
    ProgressUpdateView(
        book: .sampleCurrentlyReading,
        previousPage: 100,
        readingPace: 18.0
    ) { _, _ in }
}

#Preview("Without Page Count") {
    let book = Book(
        isbn: "0000000000",
        title: "No Page Count Book",
        authors: ["Author"],
        readStatus: .currentlyReading
    )
    ProgressUpdateView(
        book: book,
        previousPage: nil,
        readingPace: nil
    ) { _, _ in }
}
#endif
