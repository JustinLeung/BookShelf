import SwiftUI

struct TimerMiniPlayerView: View {
    @Bindable var timerViewModel: ReadingTimerViewModel
    @Bindable var viewModel: BookshelfViewModel
    @State private var showTimerView = false

    var body: some View {
        Button {
            showTimerView = true
        } label: {
            HStack(spacing: 12) {
                if let book = timerViewModel.currentBook {
                    BookCoverView(coverData: book.coverImageData, title: book.title, cornerRadius: 4)
                        .frame(width: 36, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text(timerViewModel.formattedTime)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    if timerViewModel.state == .running {
                        Button {
                            timerViewModel.pause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.body)
                        }
                    } else {
                        Button {
                            timerViewModel.resume()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.body)
                        }
                    }
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTimerView) {
            ReadingTimerView(timerViewModel: timerViewModel, viewModel: viewModel)
        }
    }
}

#if DEBUG
#Preview("Mini Player") {
    VStack {
        Spacer()
        TimerMiniPlayerView(timerViewModel: ReadingTimerViewModel(), viewModel: BookshelfViewModel())
    }
}
#endif
