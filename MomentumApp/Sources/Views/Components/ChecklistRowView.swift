import SwiftUI

struct ChecklistRowView: View {
    let item: ChecklistItem
    let isTransitioning: Bool
    let isFadingIn: Bool
    let onToggle: () -> Void

    @State private var hasAppeared = false

    init(item: ChecklistItem, isTransitioning: Bool = false, isFadingIn: Bool = false, onToggle: @escaping () -> Void) {
        self.item = item
        self.isTransitioning = isTransitioning
        self.isFadingIn = isFadingIn
        self.onToggle = onToggle
    }

    var body: some View {
        Toggle(
            item.text,
            isOn: .init(
                get: { item.on },
                set: { newValue in
                    // Only allow checking (on: false -> true), never unchecking
                    if !item.on && newValue {
                        onToggle()
                    }
                }
            )
        )
        .toggleStyle(.checklist)
        .animation(nil, value: item.on)  // Prevent inherited animations on checkbox state
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(backgroundGradient)
        .contentShape(Rectangle())  // Ensure the entire row is clickable
        .cornerRadius(2)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(borderColor, lineWidth: 2)
        )
        .opacity(opacity)
        .offset(x: offsetX)
        .animation(.easeOut(duration: 0.3), value: isTransitioning)
        .animation(.easeOut(duration: 0.3), value: hasAppeared)
        .allowsHitTesting(!isTransitioning && (!isFadingIn || hasAppeared))  // Enable clicks after fade-in completes
        .onHover { isHovered in
            if isHovered && !isTransitioning && (!isFadingIn || hasAppeared) {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onAppear {
            if isFadingIn {
                // Slight delay to ensure the view is ready before animating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasAppeared = true
                    }
                }
            } else {
                hasAppeared = true
            }
        }
    }

    private var backgroundGradient: some View {
        Group {
            if item.on {
                LinearGradient(
                    colors: [Color(hex: "FDF9F1"), Color(hex: "F9F7F4")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color.white
            }
        }
    }

    private var borderColor: Color {
        item.on ? Color.accentGold : Color.borderNeutral
    }

    private var opacity: Double {
        if isTransitioning {
            0
        } else if isFadingIn && !hasAppeared {
            0
        } else {
            1
        }
    }

    private var offsetX: CGFloat {
        if isTransitioning {
            -10
        } else if isFadingIn && !hasAppeared {
            10
        } else {
            0
        }
    }
}

// Add hex color initializer if not already present
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
