import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: BookshelfViewModel
    @Bindable var timerViewModel: ReadingTimerViewModel

    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                CurrentlyReadingView(viewModel: viewModel, timerViewModel: timerViewModel)
                    .tabItem {
                        Label("Reading", systemImage: "book.fill")
                    }
                    .tag(0)

                BookshelfView(viewModel: viewModel, timerViewModel: timerViewModel)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }
                    .tag(1)

                StatsView(viewModel: viewModel)
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    .tag(2)
            }

            if timerViewModel.state != .idle {
                TimerMiniPlayerView(timerViewModel: timerViewModel, viewModel: viewModel)
                    .padding(.bottom, 49) // tab bar height
            }
        }
    }
}

#if DEBUG
#Preview("Main Tab View") {
    MainTabView(viewModel: BookshelfViewModel(), timerViewModel: ReadingTimerViewModel())
        .modelContainer(Book.previewContainer)
}
#endif
