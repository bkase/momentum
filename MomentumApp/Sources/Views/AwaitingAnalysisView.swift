import SwiftUI
import ComposableArchitecture

struct AwaitingAnalysisView: View {
    @Bindable var store: StoreOf<ReflectionFeature>
    
    var body: some View {
        VStack(spacing: 0) {
            // Title section
            Text("Reflection Complete")
                .momentumTitleStyle()
                .padding(CGFloat.momentumSpacingLarge)
            
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
                        .buttonStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .keyboardShortcut("o", modifiers: .command)
                        
                        Button("New Session") {
                            store.send(.cancelButtonTapped)
                        }
                        .buttonStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .keyboardShortcut("n", modifiers: .command)
                    }
                }
                
                // Operation error
                OperationErrorView(error: store.operationError)
            }
        }
        .momentumContainer()
    }
}
