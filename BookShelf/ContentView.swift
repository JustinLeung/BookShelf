import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("streakReminderEnabled") private var streakReminderEnabled = false
    @State private var viewModel = BookshelfViewModel()

    var body: some View {
        BookshelfView(viewModel: viewModel)
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
            .task {
                if streakReminderEnabled {
                    NotificationService.shared.scheduleStreakReminderIfNeeded(
                        currentStreak: viewModel.currentStreak(),
                        hasReadToday: viewModel.hasReadToday()
                    )
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView()
            }
    }
}

#if DEBUG
#Preview("With Books") {
    ContentView()
        .modelContainer(Book.previewContainer)
}

#Preview("Empty") {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
#endif
