import SwiftUI

// MARK: - View Modifiers for Consistent Styling

extension View {
    /// Applies the standard Momentum container styling
    func momentumContainer() -> some View {
        self
            .frame(width: .momentumContainerWidth)
            .padding(.top, .momentumContainerPaddingTop)
            .padding(.horizontal, .momentumContainerPaddingHorizontal)
            .padding(.bottom, .momentumContainerPaddingBottom)
            .background(Color.canvasBackground)
    }

    /// Applies the standard title styling
    func momentumTitleStyle() -> some View {
        self
            .font(.momentumTitle)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, .momentumTitleBottomPadding)
    }

    /// Applies section label styling
    func momentumSectionLabel() -> some View {
        self
            .font(.sectionLabel)
            .foregroundStyle(Color.textSecondary)
    }

    /// Applies standard body text styling
    func momentumBodyText() -> some View {
        self
            .font(.system(size: 14))
            .foregroundStyle(Color.textPrimary)
            .lineSpacing(4)
    }

    /// Applies secondary text styling
    func momentumSecondaryText() -> some View {
        self
            .font(.system(size: 14))
            .foregroundStyle(Color.textSecondary)
    }

    /// Standard content card styling with border
    func momentumCard() -> some View {
        self
            .padding(.momentumFieldPaddingHorizontal)
            .padding(.vertical, .momentumFieldPaddingVertical)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: .momentumCornerRadiusMain)
                    .stroke(Color.borderNeutral, lineWidth: .momentumBorderWidthNeutral)
            )
    }
}

// MARK: - Button Styles

/// Secondary button style for less prominent actions
struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundStyle(isHovered ? Color.textPrimary : Color.textSecondary)
            .padding(.horizontal, .momentumButtonPaddingHorizontal)
            .padding(.vertical, .momentumSpacingMedium)
            .background(
                RoundedRectangle(cornerRadius: .momentumCornerRadiusMain)
                    .fill(Color.white.opacity(isHovered ? 1 : 0))
                    .overlay(
                        RoundedRectangle(cornerRadius: .momentumCornerRadiusMain)
                            .stroke(Color.borderNeutral, lineWidth: .momentumBorderWidthNeutral)
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeOut(duration: CGFloat.momentumAnimationDurationQuick), value: isHovered)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle {
        SecondaryButtonStyle()
    }
}

// MARK: - Layout Helpers

extension View {
    /// Standard section spacing wrapper
    func momentumSection() -> some View {
        VStack(alignment: .leading, spacing: .momentumSpacingMedium) {
            self
        }
    }

    /// Main content sections wrapper with standard spacing
    func momentumContentSections(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: .momentumSectionSpacing) {
            self
            content()
        }
    }
}
