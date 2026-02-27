import SwiftUI

struct CircularProgressRing: View {
    let progress: Double
    var size: CGFloat = 160
    var lineWidth: CGFloat = 12
    var showPercentage: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedProgress: Double = 0

    private var clampedProgress: Double {
        min(1.0, max(0.0, progress))
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(AppTheme.Colors.progressTrack(colorScheme), lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.accentColor.opacity(0.7), .accentColor]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedProgress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage label
            if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: size * 0.22, weight: .bold, design: .serif))
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = clampedProgress
            }
        }
        .onChange(of: progress) {
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = clampedProgress
            }
        }
    }
}

#if DEBUG
#Preview("0%") {
    CircularProgressRing(progress: 0.0)
        .padding()
}

#Preview("38%") {
    CircularProgressRing(progress: 0.38)
        .padding()
}

#Preview("75%") {
    CircularProgressRing(progress: 0.75)
        .padding()
}

#Preview("100%") {
    CircularProgressRing(progress: 1.0)
        .padding()
}

#Preview("Compact") {
    CircularProgressRing(progress: 0.62, size: 80, lineWidth: 6)
        .padding()
}
#endif
