import SwiftUI

struct StarRatingView: View {
    let rating: Int?
    let interactive: Bool
    var starSize: CGFloat = 24
    var onRate: ((Int?) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundStyle(star <= (rating ?? 0) ? AppTheme.Colors.amber : .gray.opacity(0.4))
                    .onTapGesture {
                        guard interactive else { return }
                        if rating == star {
                            onRate?(nil)
                        } else {
                            onRate?(star)
                        }
                    }
            }
        }
    }
}

#if DEBUG
#Preview("5 Stars") {
    StarRatingView(rating: 5, interactive: false)
        .padding()
}

#Preview("3 Stars") {
    StarRatingView(rating: 3, interactive: false)
        .padding()
}

#Preview("No Rating") {
    StarRatingView(rating: nil, interactive: false)
        .padding()
}

#Preview("Interactive") {
    @Previewable @State var rating: Int? = 2
    StarRatingView(rating: rating, interactive: true, starSize: 32) { newRating in
        rating = newRating
    }
    .padding()
}
#endif
