import SwiftUI

struct ProgressUpdateView: View {
    let book: Book
    let onSave: (Int?, Double?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pageText: String = ""
    @State private var sliderValue: Double = 0.0

    private var hasPageCount: Bool {
        book.pageCount != nil && book.pageCount! > 0
    }

    private var enteredPage: Int? {
        Int(pageText)
    }

    private var liveProgress: Double? {
        if hasPageCount, let page = enteredPage, let total = book.pageCount {
            return min(1.0, max(0.0, Double(page) / Double(total)))
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(book.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top)

                if hasPageCount {
                    pageInputSection
                } else {
                    percentageSliderSection
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

            if let progress = liveProgress {
                ReadingProgressBar(progress: progress, height: 8, showLabel: true)
                    .padding(.horizontal, 40)
            }
        }
    }

    private var percentageSliderSection: some View {
        VStack(spacing: 16) {
            Text("\(Int(sliderValue * 100))%")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Slider(value: $sliderValue, in: 0...1, step: 0.01)
                .padding(.horizontal, 40)

            ReadingProgressBar(progress: sliderValue, height: 8)
                .padding(.horizontal, 40)

            Text("No page count available — set progress manually")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview("With Page Count") {
    ProgressUpdateView(book: .sampleCurrentlyReading) { _, _ in }
}

#Preview("Without Page Count") {
    let book = Book(
        isbn: "0000000000",
        title: "No Page Count Book",
        authors: ["Author"],
        readStatus: .currentlyReading
    )
    ProgressUpdateView(book: book) { _, _ in }
}
#endif
