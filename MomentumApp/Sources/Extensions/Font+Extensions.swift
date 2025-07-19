import SwiftUI

extension Font {
    // Use New York (serif) for title and button like in HTML
    static let momentumTitle = Font.custom("New York", size: 28)
        .weight(.regular)
    static let momentumTitleFallback = Font.system(size: 28, weight: .regular, design: .serif)

    static let sanctuaryButtonFont = Font.custom("New York", size: 18)
        .italic()
        .weight(.regular)
    static let sanctuaryButtonFallback = Font.system(size: 18, weight: .regular, design: .serif)
        .italic()

    // System fonts for other elements
    static let sectionLabel = Font.system(size: 11, weight: .semibold)
    static let intentionField = Font.system(size: 16, weight: .regular)
    static let durationLabel = Font.system(size: 14, weight: .regular)
    static let durationInput = Font.system(size: 15, weight: .medium)
    static let checklistItem = Font.system(size: 14, weight: .regular)
    static let progressIndicator = Font.system(size: 11, weight: .medium)
}
