import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPageView(
                    icon: "books.vertical.fill",
                    title: "Welcome to BookShelf",
                    subtitle: "Your personal reading companion",
                    features: [
                        ("barcode.viewfinder", "Scan book barcodes instantly"),
                        ("magnifyingglass", "Search by title or ISBN"),
                        ("bookmark.fill", "Track your reading progress")
                    ]
                )
                .tag(0)

                OnboardingPageView(
                    icon: "plus.circle.fill",
                    title: "Add Books Easily",
                    subtitle: "Multiple ways to build your library",
                    features: [
                        ("barcode.viewfinder", "Scan ISBN barcodes with your camera"),
                        ("text.viewfinder", "Use cover OCR to recognize book text"),
                        ("magnifyingglass", "Search by title or author manually")
                    ]
                )
                .tag(1)

                OnboardingPageView(
                    icon: "bookmark.fill",
                    title: "Track Your Reading",
                    subtitle: "Stay on top of your reading journey",
                    features: [
                        ("book.closed", "Mark books as Want to Read"),
                        ("book", "Track what you're Currently Reading"),
                        ("star.fill", "Rate books you've finished reading")
                    ]
                )
                .tag(2)

                OnboardingPageView(
                    icon: "chart.bar.fill",
                    title: "Stats & Goals",
                    subtitle: "Build a reading habit that sticks",
                    features: [
                        ("flame.fill", "Track reading streaks day by day"),
                        ("target", "Set daily and weekly page goals"),
                        ("bell.fill", "Get gentle reminders to keep reading")
                    ]
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // Bottom button area
            VStack(spacing: 12) {
                if currentPage < pageCount - 1 {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: currentPage)

                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .sensoryFeedback(.success, trigger: hasCompletedOnboarding)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Onboarding Page

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let subtitle: String
    let features: [(icon: String, text: String)]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
                .frame(width: 100, height: 100)
                .background(Circle().fill(Color.accentColor.opacity(0.1)))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(features, id: \.text) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.accentColor.opacity(0.08)))

                        Text(feature.text)
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Onboarding Flow") {
    OnboardingView()
}

#Preview("Welcome Page") {
    OnboardingPageView(
        icon: "books.vertical.fill",
        title: "Welcome to BookShelf",
        subtitle: "Your personal reading companion",
        features: [
            ("barcode.viewfinder", "Scan book barcodes instantly"),
            ("magnifyingglass", "Search by title or ISBN"),
            ("bookmark.fill", "Track your reading progress")
        ]
    )
}

#Preview("Add Books Page") {
    OnboardingPageView(
        icon: "plus.circle.fill",
        title: "Add Books Easily",
        subtitle: "Multiple ways to build your library",
        features: [
            ("barcode.viewfinder", "Scan ISBN barcodes with your camera"),
            ("text.viewfinder", "Use cover OCR to recognize book text"),
            ("magnifyingglass", "Search by title or author manually")
        ]
    )
}

#Preview("Track Reading Page") {
    OnboardingPageView(
        icon: "bookmark.fill",
        title: "Track Your Reading",
        subtitle: "Stay on top of your reading journey",
        features: [
            ("book.closed", "Mark books as Want to Read"),
            ("book", "Track what you're Currently Reading"),
            ("star.fill", "Rate books you've finished reading")
        ]
    )
}

#Preview("Stats & Goals Page") {
    OnboardingPageView(
        icon: "chart.bar.fill",
        title: "Stats & Goals",
        subtitle: "Build a reading habit that sticks",
        features: [
            ("flame.fill", "Track reading streaks day by day"),
            ("target", "Set daily and weekly page goals"),
            ("bell.fill", "Get gentle reminders to keep reading")
        ]
    )
}
#endif
