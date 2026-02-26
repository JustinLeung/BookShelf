import SwiftUI

struct QuoteEditView: View {
    let bookISBN: String
    @State var initialText: String
    var sourceImageData: Data?
    @Bindable var viewModel: BookshelfViewModel
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var pageNumberText: String = ""

    private var pageNumber: Int? {
        Int(pageNumberText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quote Text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                }

                Section("Page Number (Optional)") {
                    TextField("Page", text: $pageNumberText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveNote(
                            bookISBN: bookISBN,
                            text: text,
                            noteType: .quote,
                            pageNumber: pageNumber,
                            sourceImageData: sourceImageData
                        )
                        dismiss()
                        onSave()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                text = initialText
            }
        }
    }
}

#if DEBUG
#Preview("Quote Edit") {
    QuoteEditView(bookISBN: "123", initialText: "Sample quote text", viewModel: BookshelfViewModel()) {}
}
#endif
