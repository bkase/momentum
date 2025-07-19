import SwiftUI

// MARK: - UI Constants
// Centralized UI constants for consistent styling across the app
// Based on PreparationView's design system

extension CGFloat {
    // MARK: - Main Container
    static let momentumContainerWidth: CGFloat = 320
    static let momentumContainerPaddingTop: CGFloat = 20
    static let momentumContainerPaddingHorizontal: CGFloat = 20
    static let momentumContainerPaddingBottom: CGFloat = 20
    
    // MARK: - Section Spacing
    static let momentumSectionSpacing: CGFloat = 24
    static let momentumTitleBottomPadding: CGFloat = 24
    static let momentumButtonSectionTopPadding: CGFloat = 24
    
    // MARK: - Component Spacing
    static let momentumFieldPaddingHorizontal: CGFloat = 16
    static let momentumFieldPaddingVertical: CGFloat = 12
    static let momentumDurationFieldPaddingHorizontal: CGFloat = 8
    static let momentumDurationFieldPaddingVertical: CGFloat = 4
    static let momentumChecklistRowPaddingHorizontal: CGFloat = 14
    static let momentumChecklistRowPaddingVertical: CGFloat = 10
    static let momentumButtonPaddingHorizontal: CGFloat = 24
    static let momentumButtonPaddingVertical: CGFloat = 14
    
    // MARK: - Checklist Specific
    static let momentumChecklistSectionSpacing: CGFloat = 12
    static let momentumChecklistItemSpacing: CGFloat = 4
    static let momentumChecklistFixedHeight: CGFloat = 156 // For 4 items
    static let momentumChecklistRowHeight: CGFloat = 36
    
    // MARK: - Small Spacing Values
    static let momentumSpacingSmall: CGFloat = 4
    static let momentumSpacingMedium: CGFloat = 8
    static let momentumSpacingLarge: CGFloat = 12
    static let momentumSpacingXLarge: CGFloat = 24
    
    // MARK: - Border and Corner Radius
    static let momentumCornerRadiusMain: CGFloat = 3
    static let momentumCornerRadiusSmall: CGFloat = 2
    static let momentumBorderWidthFocused: CGFloat = 2
    static let momentumBorderWidthNeutral: CGFloat = 1
    
    // MARK: - Shadow Values
    static let momentumShadowRadiusFocus: CGFloat = 2
    static let momentumShadowRadiusHover: CGFloat = 4
    static let momentumShadowOpacity: Double = 0.15
    
    // MARK: - Animation
    static let momentumAnimationDurationQuick: Double = 0.15
    static let momentumAnimationDurationStandard: Double = 0.3
    
    // MARK: - Other Fixed Sizes
    static let momentumDurationFieldWidth: CGFloat = 60
}
