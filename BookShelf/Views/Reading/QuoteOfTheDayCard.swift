import SwiftUI

struct QuoteOfTheDayCard: View {
    @Bindable var viewModel: BookshelfViewModel

    var body: some View {
        if let quote = viewModel.randomQuote() {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "quote.opening")
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                }

                Text(quote.text)
                    .font(.subheadline)
                    .italic()
                    .lineLimit(4)

                if let page = quote.pageNumber {
                    Text("Page \(page)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(Color.accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

#if DEBUG
#Preview("Quote Card") {
    QuoteOfTheDayCard(viewModel: BookshelfViewModel())
        .padding()
}
#endif
