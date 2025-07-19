import SwiftUI
import ComposableArchitecture

struct ActiveSessionView: View {
    @Bindable var store: StoreOf<ActiveSessionFeature>
    
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var elapsedTime: TimeInterval {
        currentTime.timeIntervalSince(store.startTime)
    }
    
    private var elapsedMinutes: Int {
        Int(elapsedTime / 60)
    }
    
    private var progress: Double {
        // expectedMinutes is already in minutes, so convert to seconds for comparison with elapsedTime
        min(elapsedTime / (Double(store.expectedMinutes) * 60), 1.0)
    }
    
    private var elapsedFormatted: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private var isOvertime: Bool {
        elapsedMinutes > Int(store.expectedMinutes)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title section
            Text("Active Session")
                .momentumTitleStyle()
            
            // Content sections
            VStack(spacing: .momentumSectionSpacing) {
                // Goal display
                VStack(spacing: .momentumSpacingMedium) {
                    Text("INTENTION")
                        .font(.sectionLabel)
                        .foregroundStyle(Color.textSecondary)
                    
                    Text(store.goal)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, .momentumFieldPaddingHorizontal)
                }
                
                // Timer display
                ZStack {
                    Circle()
                        .stroke(Color.borderNeutral, lineWidth: .momentumBorderWidthFocused)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isOvertime ? Color.red : Color.accentGold,
                            style: StrokeStyle(lineWidth: .momentumBorderWidthFocused, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    
                    VStack(spacing: .momentumSpacingSmall) {
                        Text(elapsedFormatted)
                            .font(.system(size: 36, weight: .regular, design: .serif))
                            .foregroundStyle(Color.textPrimary)
                            .contentTransition(.numericText())
                        
                        Text("of \(store.expectedMinutes) min")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(width: 180, height: 180)
                .onReceive(timer) { _ in
                    withAnimation(.linear(duration: 0.5)) {
                        currentTime = Date()
                    }
                }
                
                // Status indicators
                HStack(spacing: .momentumSpacingLarge) {
                    VStack(spacing: .momentumSpacingSmall) {
                        Text("ELAPSED")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Color.textSecondary)
                        
                        Text("\(elapsedMinutes) min")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isOvertime ? Color.red : Color.textPrimary)
                    }
                    
                    Rectangle()
                        .fill(Color.borderNeutral)
                        .frame(width: 1, height: 24)
                    
                    VStack(spacing: .momentumSpacingSmall) {
                        Text("STATUS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Color.textSecondary)
                        
                        Text(isOvertime ? "Overtime" : "In Progress")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isOvertime ? Color.red : Color.accentGold)
                    }
                }
            }
            
            // Stop button
            VStack(spacing: 0) {
                Button(action: { store.send(.stopButtonTapped) }) {
                    Text("Stop Session")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.sanctuary)
                .keyboardShortcut("s", modifiers: .command)
                
                // Operation error
                OperationErrorView(error: store.operationError)
            }
            .padding(.top, .momentumButtonSectionTopPadding)
        }
        .momentumContainer()
    }
}