import SwiftUI

// MARK: - Themed Card Modifier

struct ThemedCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Layout.cardPadding)
            .background(AppTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius))
            .shadow(color: AppTheme.Colors.espresso.opacity(colorScheme == .light ? 0.08 : 0.2), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Themed Section Title Modifier

struct ThemedSectionTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.sectionTitle)
    }
}

// MARK: - View Extensions

extension View {
    /// Replaces inline `.padding().background(systemGray6).clipShape(...)` with warm themed card.
    func themedCard() -> some View {
        modifier(ThemedCardModifier())
    }

    /// Applies serif section title font.
    func themedSectionTitle() -> some View {
        modifier(ThemedSectionTitleModifier())
    }
}
