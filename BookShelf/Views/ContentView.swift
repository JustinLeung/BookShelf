import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BookshelfViewModel()
    @State private var timerViewModel = ReadingTimerViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView(viewModel: viewModel, timerViewModel: timerViewModel)
            }
        }
        .onAppear {
            if !viewModel.isInitialized {
                viewModel.setModelContext(modelContext)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                timerViewModel.handleForeground()
            case .background, .inactive:
                timerViewModel.handleBackground()
            @unknown default:
                break
            }
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
