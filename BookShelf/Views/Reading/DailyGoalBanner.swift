import SwiftUI

struct DailyGoalBanner: View {
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let progress = viewModel.dailyGoalProgress() {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(Color.accentColor)
                    Text("Daily Goal")
                        .font(AppTheme.Typography.cardTitle)
                    Spacer()
                    Text("\(progress.pagesRead)/\(progress.goal) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.progressTrack(colorScheme))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progress.pagesRead >= progress.goal ? AppTheme.Colors.sage : Color.accentColor)
                            .frame(width: geo.size.width * min(1.0, Double(progress.pagesRead) / Double(max(progress.goal, 1))))
                    }
                }
                .frame(height: 8)

                if progress.pagesRead >= progress.goal {
                    Text("Goal reached! Keep it up!")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.sage)
                }
            }
            .themedCard()
        }
    }
}

#if DEBUG
#Preview("Daily Goal Banner") {
    DailyGoalBanner(viewModel: BookshelfViewModel())
        .padding()
}
#endif
