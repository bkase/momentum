import SwiftUI

struct IntentionTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isFocused ? Color(hex: "FDF9F1") : Color.white)
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.accentGold, lineWidth: 2)
            )
            .shadow(
                color: isFocused ? Color.black.opacity(0.15) : Color.clear,
                radius: isFocused ? 2 : 0,
                x: 0,
                y: 0
            )
            .focused($isFocused)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension TextFieldStyle where Self == IntentionTextFieldStyle {
    static var intention: IntentionTextFieldStyle {
        IntentionTextFieldStyle()
    }
}
