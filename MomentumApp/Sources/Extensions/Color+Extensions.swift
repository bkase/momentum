import SwiftUI

extension Color {
    // Main colors from HTML prototype
    static let canvasBackground = Color(red: 0.976, green: 0.969, blue: 0.957)  // #F9F7F4
    static let accentGold = Color(red: 0.780, green: 0.604, blue: 0.165)  // #C79A2A
    static let borderNeutral = Color(red: 0.890, green: 0.867, blue: 0.820)  // #E3DDD1
    static let hoverFill = Color(red: 0.992, green: 0.976, blue: 0.945)  // #FDF9F1
    static let textPrimary = Color(red: 0.067, green: 0.067, blue: 0.067)  // #111111
    static let textSecondary = Color(red: 0.427, green: 0.310, blue: 0.110)  // #6D4F1C
    static let textTertiary = Color(red: 0.600, green: 0.600, blue: 0.600)  // #999999

    // Disabled states
    static let disabledText = Color.textSecondary
    static let disabledBackground = Color.canvasBackground
    static let disabledBorder = Color.borderNeutral

    // Component-specific
    static let checkboxFill = Color.accentGold
    static let completedRowBackground = Color.hoverFill
    static let inputBackground = Color.white
}
