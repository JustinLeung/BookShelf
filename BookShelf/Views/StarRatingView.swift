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
                    .foregroundStyle(star <= (rating ?? 0) ? .yellow : .gray.opacity(0.4))
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
