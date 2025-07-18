import SwiftUI
import ComposableArchitecture

struct AwaitingAnalysisView: View {
    @Bindable var store: StoreOf<ReflectionFeature>
    
    var body: some View {
        VStack(spacing: 0) {
            // Title section
            Text("Reflection Complete")
                .font(.momentumTitle)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, .momentumTitleBottomPadding)
            
            // Content sections
            VStack(spacing: .momentumSectionSpacing) {
                // Status message
                VStack(spacing: .momentumSpacingLarge) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentGold)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Your reflection has been saved.\nReview it before seeking deeper insights.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // Action buttons
                VStack(spacing: .momentumSpacingLarge) {
                    Button("Analyze with AI") {
                        store.send(.analyzeButtonTapped)
                    }
                    .buttonStyle(.sanctuary)
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.return, modifiers: .command)
                    
                    HStack(spacing: .momentumSpacingMedium) {
                        Button("Open Reflection") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: store.reflectionPath))
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .keyboardShortcut("o", modifiers: .command)
                        
                        Button("New Session") {
                            store.send(.cancelButtonTapped)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .keyboardShortcut("n", modifiers: .command)
                    }
                }
            }
        }
        .frame(width: .momentumContainerWidth)
        .padding(.top, .momentumContainerPaddingTop)
        .padding(.horizontal, .momentumContainerPaddingHorizontal)
        .padding(.bottom, .momentumContainerPaddingBottom)
        .background(Color.canvasBackground)
    }
}

// Secondary button style for less prominent actions
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
            .animation(.easeOut(duration: .momentumAnimationDurationQuick), value: isHovered)
    }
}