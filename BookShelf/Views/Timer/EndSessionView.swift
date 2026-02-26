import SwiftUI

struct EndSessionView: View {
    @Bindable var timerViewModel: ReadingTimerViewModel
    @Bindable var viewModel: BookshelfViewModel
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var endPageText = ""
    @State private var showDiscardConfirmation = false

    private var endPage: Int? {
        Int(endPageText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("Session Complete")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(timerViewModel.formattedTime)
                        .font(.title)
                        .fontWeight(.light)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                if let book = timerViewModel.currentBook {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(book.title)
                            .font(.headline)

                        if let currentPage = book.currentPage {
                            Text("Started at page \(currentPage)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        TextField("Ending page", text: $endPageText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)

                        if let endPage, let startPage = book.currentPage, endPage > startPage {
                            let pagesRead = endPage - startPage
                            let duration = timerViewModel.displayTime
                            let pagesPerHour = duration > 0 ? Double(pagesRead) / (duration / 3600.0) : 0

                            HStack {
                                Label("\(pagesRead) pages", systemImage: "book.pages")
                                Spacer()
                                if pagesPerHour > 0 {
                                    Label("\(Int(pagesPerHour)) pg/hr", systemImage: "speedometer")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        timerViewModel.endSession(endPage: endPage, modelContext: modelContext)
                        viewModel.fetchBooks()
                        dismiss()
                        onDismiss()
                    } label: {
                        Text("Save Session")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(role: .destructive) {
                        showDiscardConfirmation = true
                    } label: {
                        Text("Discard Session")
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .navigationTitle("End Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Discard Session?", isPresented: $showDiscardConfirmation) {
                Button("Discard", role: .destructive) {
                    timerViewModel.cancelSession()
                    dismiss()
                    onDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your reading session data will be lost.")
            }
            .onAppear {
                if let book = timerViewModel.currentBook, let page = book.currentPage {
                    endPageText = "\(page)"
                }
            }
        }
    }
}

#if DEBUG
#Preview("End Session") {
    EndSessionView(timerViewModel: ReadingTimerViewModel(), viewModel: BookshelfViewModel()) {}
}
#endif
