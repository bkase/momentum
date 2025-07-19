import SwiftUI

struct SanctuaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .serif).italic())
            .tracking(0.5)
            .foregroundStyle(foregroundColor(isHovered: isHovered, isPressed: configuration.isPressed))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(backgroundColor(isHovered: isHovered, isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(borderColor(isHovered: isHovered), lineWidth: 2)
            )
            .offset(y: offsetY(isHovered: isHovered, isPressed: configuration.isPressed))
            .shadow(
                color: shadowColor(isHovered: isHovered, isPressed: configuration.isPressed),
                radius: shadowRadius(isHovered: isHovered, isPressed: configuration.isPressed),
                x: 0,
                y: shadowY(isHovered: isHovered, isPressed: configuration.isPressed)
            )
            .opacity(isEnabled ? 1.0 : 0.3)
            .onHover { hovering in
                if isEnabled {
                    isHovered = hovering
                }
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private func foregroundColor(isHovered: Bool, isPressed: Bool) -> Color {
        guard isEnabled else { return Color.textPrimary }
        return isHovered ? .white : Color.textPrimary
    }

    private func backgroundColor(isHovered: Bool, isPressed: Bool) -> Color {
        guard isEnabled else { return Color.white }
        return isHovered ? Color.accentGold : Color.white
    }

    private func borderColor(isHovered: Bool) -> Color {
        guard isEnabled else { return Color.borderNeutral }
        return Color.accentGold
    }

    private func offsetY(isHovered: Bool, isPressed: Bool) -> CGFloat {
        guard isEnabled else { return 0 }
        if isPressed { return 0 }
        return isHovered ? -1 : 0
    }

    private func shadowColor(isHovered: Bool, isPressed: Bool) -> Color {
        guard isEnabled && isHovered else { return Color.clear }
        return Color.black.opacity(0.15)
    }

    private func shadowRadius(isHovered: Bool, isPressed: Bool) -> CGFloat {
        guard isEnabled && isHovered else { return 0 }
        return isPressed ? 2 : 4
    }

    private func shadowY(isHovered: Bool, isPressed: Bool) -> CGFloat {
        guard isEnabled && isHovered else { return 0 }
        return isPressed ? 1 : 2
    }
}

extension ButtonStyle where Self == SanctuaryButtonStyle {
    static var sanctuary: SanctuaryButtonStyle {
        SanctuaryButtonStyle()
    }
}
