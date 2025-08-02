import SwiftUI

struct ChecklistToggleStyle: ToggleStyle {
    @State private var isHovered = false
    @State private var isPressed = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            // Fixed-size container to prevent layout shifts during animations
            Rectangle()
                .fill(Color.clear)
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(checkboxFill(isOn: configuration.isOn))
                        .frame(width: 16, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(checkboxBorder(isOn: configuration.isOn, isHovered: isHovered), lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(configuration.isOn ? 1 : 0)
                                .scaleEffect(configuration.isOn ? 1 : 0.5)
                        )
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: isPressed)
                        .animation(.easeOut(duration: 0.2), value: configuration.isOn)
                )

            configuration.label
                .font(.system(size: 14))
                .foregroundStyle(configuration.isOn ? Color.textSecondary : Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            isPressed = true
            configuration.isOn.toggle()

            // Reset pressed state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func checkboxFill(isOn: Bool) -> Color {
        isOn ? Color.accentGold : Color.clear
    }

    private func checkboxBorder(isOn: Bool, isHovered: Bool) -> Color {
        if isOn {
            Color.accentGold
        } else if isHovered {
            Color.accentGold
        } else {
            Color.borderNeutral
        }
    }
}

extension ToggleStyle where Self == ChecklistToggleStyle {
    static var checklist: ChecklistToggleStyle {
        ChecklistToggleStyle()
    }
}
