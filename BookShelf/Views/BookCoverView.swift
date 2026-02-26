import SwiftUI

struct BookCoverView: View {
    let coverData: Data?
    let title: String
    let cornerRadius: CGFloat

    @State private var decodedImage: UIImage?

    init(coverData: Data?, title: String, cornerRadius: CGFloat = 8) {
        self.coverData = coverData
        self.title = title
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let decodedImage {
                Image(uiImage: decodedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
            }
        }
        .task(id: coverData) {
            guard let data = coverData else { return }
            let image = await Task.detached {
                UIImage(data: data)
            }.value
            decodedImage = image
        }
    }

    private var placeholder: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Spine line on left edge
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 3)

            VStack {
                Image(systemName: "book.closed.fill")
                    .font(cornerRadius > 8 ? .system(size: 48) : .title2)
                    .foregroundStyle(Color.accentColor.opacity(0.5))

                if cornerRadius <= 8 {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                        .lineLimit(3)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("With Cover Data") {
    BookCoverView(coverData: nil, title: "Sample Book")
        .frame(width: 140, height: 160)
        .padding()
}

#Preview("Placeholder - Grid") {
    BookCoverView(coverData: nil, title: "A Long Book Title That Wraps")
        .frame(width: 140, height: 160)
        .padding()
}

#Preview("Placeholder - Detail") {
    BookCoverView(coverData: nil, title: "Sample Book", cornerRadius: 12)
        .frame(width: 200, height: 280)
        .padding()
}
#endif
