import SwiftUI
import ComposableArchitecture

struct AnalysisResultView: View {
    @Bindable var store: StoreOf<AnalysisFeature>
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Title section
                Text("Session Insights")
                    .font(.momentumTitle)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, .momentumTitleBottomPadding)
                
                // Content sections
                VStack(alignment: .leading, spacing: .momentumSectionSpacing) {
                    // Summary section
                    VStack(alignment: .leading, spacing: .momentumSpacingMedium) {
                        Text("SUMMARY")
                            .font(.sectionLabel)
                            .foregroundStyle(Color.textSecondary)
                        
                        Text(store.analysis.summary)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, .momentumSpacingSmall)
                    }
                    
                    // Suggestion section
                    VStack(alignment: .leading, spacing: .momentumSpacingMedium) {
                        Text("SUGGESTION")
                            .font(.sectionLabel)
                            .foregroundStyle(Color.textSecondary)
                        
                        Text(store.analysis.suggestion)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, .momentumSpacingSmall)
                    }
                    
                    // Reasoning section
                    VStack(alignment: .leading, spacing: .momentumSpacingMedium) {
                        Text("REASONING")
                            .font(.sectionLabel)
                            .foregroundStyle(Color.textSecondary)
                        
                        Text(store.analysis.reasoning)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, .momentumSpacingSmall)
                    }
                }
                
                // Button section
                VStack(spacing: 0) {
                    Button("Begin New Sanctuary") {
                        store.send(.resetButtonTapped)
                    }
                    .buttonStyle(.sanctuary)
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut("n", modifiers: .command)
                }
                .padding(.top, .momentumButtonSectionTopPadding)
            }
            .frame(width: .momentumContainerWidth)
            .padding(.top, .momentumContainerPaddingTop)
            .padding(.horizontal, .momentumContainerPaddingHorizontal)
            .padding(.bottom, .momentumContainerPaddingBottom)
        }
        .background(Color.canvasBackground)
    }
}