import SwiftUI

enum AppTheme {

    // MARK: - Colors

    enum Colors {

        /// Warm page background — light parchment / dark walnut
        static func pageBackground(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .light
                ? Color(red: 250/255, green: 245/255, blue: 238/255)   // #FAF5EE
                : Color(red: 31/255, green: 26/255, blue: 23/255)      // #1F1A17
        }

        /// Card surface — warm linen / dark leather
        static func cardBackground(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .light
                ? Color(red: 245/255, green: 237/255, blue: 227/255)   // #F5EDE3
                : Color(red: 46/255, green: 38/255, blue: 33/255)      // #2E2621
        }

        /// Progress track — muted parchment / dark grain
        static func progressTrack(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .light
                ? Color(red: 230/255, green: 219/255, blue: 207/255)   // #E6DBCF
                : Color(red: 64/255, green: 56/255, blue: 51/255)      // #403833
        }

        /// Warm amber — stars, streaks
        static let amber = Color(red: 204/255, green: 148/255, blue: 51/255)    // #CC9433

        /// Terracotta — warm highlight
        static let terracotta = Color(red: 194/255, green: 110/255, blue: 82/255) // #C26E52

        /// Sage green — success states
        static let sage = Color(red: 140/255, green: 166/255, blue: 128/255)    // #8CA680

        /// Espresso brown — deep anchor color
        static let espresso = Color(red: 77/255, green: 56/255, blue: 46/255)   // #4D382E
    }

    // MARK: - Gradients

    enum Gradients {

        /// Subtle warm card gradient (top-leading to bottom-trailing)
        static func warmCard(_ colorScheme: ColorScheme) -> LinearGradient {
            LinearGradient(
                colors: [
                    Colors.cardBackground(colorScheme),
                    Colors.cardBackground(colorScheme).opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Accent gradient — plum to terracotta
        static let accent = LinearGradient(
            colors: [Color.accentColor, Colors.terracotta],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// Brand gradient — espresso to dark plum (launch/onboarding)
        static let brand = LinearGradient(
            colors: [Colors.espresso, Color(red: 90/255, green: 50/255, blue: 70/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography

    enum Typography {

        /// Section titles — serif bold
        static let sectionTitle: Font = .system(.title2, design: .serif, weight: .bold)

        /// Card titles — serif semibold
        static let cardTitle: Font = .system(.subheadline, design: .serif, weight: .semibold)

        /// Large display text — timer, hero stats
        static func display(size: CGFloat = 48) -> Font {
            .system(size: size, weight: .light, design: .serif)
        }
    }

    // MARK: - Layout

    enum Layout {
        static let cardCornerRadius: CGFloat = 16
        static let smallCornerRadius: CGFloat = 10
        static let cardPadding: CGFloat = 16
    }
}
