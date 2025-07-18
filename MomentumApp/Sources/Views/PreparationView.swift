import SwiftUI
import ComposableArchitecture

struct PreparationView: View {
    @Bindable var store: StoreOf<PreparationFeature>
    @FocusState private var isGoalFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            titleSection
            
            VStack(alignment: .leading, spacing: 24) {
                intentionInput
                durationPicker
                checklistSection
            }
            
            buttonAndProgress
        }
        .frame(width: 320)
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.canvasBackground)
        .onAppear {
            isGoalFieldFocused = true
            store.send(.onAppear)
        }
    }
    
    private var titleSection: some View {
        Text("Compose Your Intention")
            .font(.momentumTitle)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
    }
    
    private var intentionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("What will you accomplish?", text: Binding(
                get: { store.goal },
                set: { store.send(.goalChanged($0)) }
            ))
            .textFieldStyle(.intention)
            .focused($isGoalFieldFocused)
            .onSubmit {
                if store.isStartButtonEnabled {
                    startSession()
                }
            }
            
            if let error = store.goalValidationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private var durationPicker: some View {
        HStack(spacing: 8) {
            Text("Estimated duration")
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
            
            TextField("30", text: Binding(
                get: { store.timeInput },
                set: { store.send(.timeInputChanged($0)) }
            ))
            .frame(width: 60)
            .multilineTextAlignment(.center)
            .font(.system(size: 15, weight: .medium))
            .textFieldStyle(DurationTextFieldStyle())
            .onSubmit {
                if store.isStartButtonEnabled {
                    startSession()
                }
            }
            
            Text("min")
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
        }
    }
    
    @ViewBuilder
    private var checklistSection: some View {
        if !store.checklistSlots.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("GROUNDING RITUAL")
                    .font(.sectionLabel)
                    .foregroundStyle(Color.textSecondary)
                    .tracking(2)
                
                // Fixed height container for 4 items
                VStack(spacing: 4) {
                    ForEach(store.checklistSlots) { slot in
                        checklistSlotView(for: slot)
                    }
                }
                .frame(height: 156) // Fixed height for 4 items
            }
        }
    }
    
    @ViewBuilder
    private func checklistSlotView(for slot: PreparationFeature.ChecklistSlot) -> some View {
        Group {
            if let item = slot.item {
                ChecklistRowView(
                    item: item,
                    isTransitioning: slot.isTransitioning,
                    isFadingIn: slot.isFadingIn,
                    onToggle: {
                        store.send(.checklistSlotToggled(slotId: slot.id))
                    }
                )
                .id(item.id) // Force view recreation when item changes
            } else {
                // Empty slot maintains the space
                Color.clear
                    .frame(height: 36) // Height of a checklist row
            }
        }
    }
    
    private var buttonAndProgress: some View {
        VStack(spacing: 8) {
            Button("Enter Sanctuary") {
                startSession()
            }
            .buttonStyle(SanctuaryButtonStyle())
            .disabled(!store.isStartButtonEnabled)
            .keyboardShortcut(.return, modifiers: .command)
            
            // Progress indicator
            Text("\(store.totalItemsCompleted) of 10 completed")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .opacity(store.totalItemsCompleted > 0 ? 1 : 0)
        }
        .padding(.top, 24)
    }
    
    private func startSession() {
        store.send(.startButtonTapped)
    }
}

// Duration text field style
struct DurationTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "FDF9F1"))
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.borderNeutral, lineWidth: 1)
            )
    }
}