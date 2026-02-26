import SwiftUI

struct ChallengeSetupView: View {
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var goalCount: Int = 12
    private let isEditing: Bool
    private let year: Int

    init(viewModel: BookshelfViewModel) {
        self.viewModel = viewModel
        let currentYear = Calendar.current.component(.year, from: Date())
        self.year = currentYear
        if let existing = viewModel.fetchChallenge(for: currentYear) {
            self._goalCount = State(initialValue: existing.goalCount)
            self.isEditing = true
        } else {
            self.isEditing = false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("**\(goalCount)** books in \(String(year))", value: $goalCount, in: 1...100, step: 1)
                } footer: {
                    Text("That's about \(booksPerMonth) book\(booksPerMonth == 1 ? "" : "s") per month")
                }

                if isEditing {
                    Section {
                        Button("Delete Challenge", role: .destructive) {
                            viewModel.deleteChallenge(for: year)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("\(String(year)) Reading Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveChallenge(year: year, goalCount: goalCount)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var booksPerMonth: Int {
        max(1, Int(round(Double(goalCount) / 12.0)))
    }
}

#if DEBUG
#Preview("Challenge Setup") {
    ChallengeSetupView(viewModel: BookshelfViewModel())
        .modelContainer(Book.previewContainer)
}
#endif
