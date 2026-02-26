import SwiftUI

struct ReadingProgressBar: View {
    let progress: Double
    var height: CGFloat = 4
    var showLabel: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: height)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * clampedProgress, height: height)
                }
            }
            .frame(height: height)

            if showLabel {
                Text("\(Int(clampedProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var clampedProgress: Double {
        min(1.0, max(0.0, progress))
    }
}

#if DEBUG
#Preview("0%") {
    ReadingProgressBar(progress: 0.0, showLabel: true)
        .padding()
}

#Preview("38%") {
    ReadingProgressBar(progress: 0.38, showLabel: true)
        .padding()
}

#Preview("75%") {
    ReadingProgressBar(progress: 0.75, showLabel: true)
        .padding()
}

#Preview("100%") {
    ReadingProgressBar(progress: 1.0, showLabel: true)
        .padding()
}
#endif
