import SwiftUI

struct StreakBadge: View {
    @Bindable var viewModel: BookshelfViewModel

    private var streak: Int { viewModel.currentStreak() }

    private var milestoneMessage: String? {
        switch streak {
        case 7: return "One week streak!"
        case 30: return "One month streak!"
        case 100: return "100 days - incredible!"
        case 365: return "One year streak!"
        default: return nil
        }
    }

    var body: some View {
        if streak > 0 {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(streak >= 7 ? AppTheme.Colors.amber : Color.accentColor)
                        .font(.title2)

                    Text("\(streak)")
                        .font(AppTheme.Typography.sectionTitle)

                    Text(streak == 1 ? "day" : "days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let message = milestoneMessage {
                    Text(message)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.amber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.amber.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .themedCard()
        }
    }
}

#if DEBUG
#Preview("Streak Badge") {
    StreakBadge(viewModel: BookshelfViewModel())
        .padding()
}
#endif
