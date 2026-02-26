import SwiftUI

struct DailyGoalBanner: View {
    @Bindable var viewModel: BookshelfViewModel

    var body: some View {
        if let progress = viewModel.dailyGoalProgress() {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(Color.accentColor)
                    Text("Daily Goal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(progress.pagesRead)/\(progress.goal) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progress.pagesRead >= progress.goal ? Color.green : Color.accentColor)
                            .frame(width: geo.size.width * min(1.0, Double(progress.pagesRead) / Double(max(progress.goal, 1))))
                    }
                }
                .frame(height: 8)

                if progress.pagesRead >= progress.goal {
                    Text("Goal reached! Keep it up!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#if DEBUG
#Preview("Daily Goal Banner") {
    DailyGoalBanner(viewModel: BookshelfViewModel())
        .padding()
}
#endif
