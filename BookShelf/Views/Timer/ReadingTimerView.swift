import SwiftUI

struct ReadingTimerView: View {
    @Bindable var timerViewModel: ReadingTimerViewModel
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEndSession = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                if let book = timerViewModel.currentBook {
                    BookCoverView(coverData: book.coverImageData, title: book.title, cornerRadius: 12)
                        .frame(height: 160)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                    Text(book.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text(timerViewModel.formattedTime)
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .contentTransition(.numericText())

                HStack(spacing: 32) {
                    if timerViewModel.state == .running {
                        Button {
                            timerViewModel.pause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.title)
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(Color.orange))
                                .foregroundStyle(.white)
                        }
                    } else if timerViewModel.state == .paused {
                        Button {
                            timerViewModel.resume()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(Color.green))
                                .foregroundStyle(.white)
                        }
                    }

                    Button {
                        showEndSession = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(Color.red))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reading Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Minimize") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEndSession) {
                EndSessionView(timerViewModel: timerViewModel, viewModel: viewModel) {
                    dismiss()
                }
            }
        }
    }
}

#if DEBUG
#Preview("Reading Timer") {
    ReadingTimerView(timerViewModel: ReadingTimerViewModel(), viewModel: BookshelfViewModel())
}
#endif
