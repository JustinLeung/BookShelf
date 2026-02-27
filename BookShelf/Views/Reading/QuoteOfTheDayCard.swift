import SwiftUI

struct QuoteOfTheDayCard: View {
    @Bindable var viewModel: BookshelfViewModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let quote = viewModel.randomQuote() {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "quote.opening")
                        .foregroundStyle(AppTheme.Colors.terracotta)
                    Spacer()
                }

                Text(quote.text)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .lineLimit(4)

                if let page = quote.pageNumber {
                    Text("Page \(page)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(AppTheme.Layout.cardPadding)
            .background(AppTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius)
                    .stroke(AppTheme.Colors.terracotta.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: AppTheme.Colors.espresso.opacity(colorScheme == .light ? 0.06 : 0.15), radius: 4, x: 0, y: 2)
        }
    }
}

#if DEBUG
#Preview("Quote Card") {
    QuoteOfTheDayCard(viewModel: BookshelfViewModel())
        .padding()
}
#endif
