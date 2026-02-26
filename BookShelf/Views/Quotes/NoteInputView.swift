import SwiftUI

struct NoteInputView: View {
    let bookISBN: String
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var pageNumberText = ""
    @State private var isQuote = false

    private var pageNumber: Int? {
        Int(pageNumberText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isQuote) {
                        Text("Note").tag(false)
                        Text("Quote").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section(isQuote ? "Quote" : "Note") {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                }

                Section("Page Number (Optional)") {
                    TextField("Page", text: $pageNumberText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(isQuote ? "Add Quote" : "Add Note")
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
                            noteType: isQuote ? .quote : .note,
                            pageNumber: pageNumber
                        )
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Note Input") {
    NoteInputView(bookISBN: "123", viewModel: BookshelfViewModel())
}
#endif
