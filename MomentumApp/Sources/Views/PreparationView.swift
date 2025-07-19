import ComposableArchitecture
import SwiftUI

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
        .momentumContainer()
        .onAppear {
            isGoalFieldFocused = true
            store.send(.onAppear)
        }
    }

    private var titleSection: some View {
        Text("Compose Your Intention")
            .momentumTitleStyle()
    }

    private var intentionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "What will you accomplish?",
                text: Binding(
                    get: { store.goal },
                    set: { store.send(.goalChanged($0)) }
                )
            )
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

            TextField(
                "30",
                text: Binding(
                    get: { store.timeInput },
                    set: { store.send(.timeInputChanged($0)) }
                )
            )
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
        VStack(alignment: .leading, spacing: 12) {
            Text("GROUNDING RITUAL")
                .font(.sectionLabel)
                .foregroundStyle(Color.textSecondary)
                .tracking(2)

            if store.isLoadingChecklist {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
                    .frame(height: 36)
            } else {
                VStack(spacing: 4) {
                    ForEach(store.checklistSlots) { slot in
                        if let item = slot.item {
                            ChecklistRowView(
                                item: item,
                                isTransitioning: slot.isTransitioning,
                                isFadingIn: slot.isFadingIn,
                                onToggle: {
                                    store.send(.checklistSlotToggled(slotId: slot.id))
                                }
                            )
                        } else {
                            // Empty slot
                            Color.clear
                                .frame(height: 36)
                        }
                    }
                }
            }
        }
    }

    private var buttonAndProgress: some View {
        VStack(spacing: 6) {
            Button("Enter Sanctuary") {
                startSession()
            }
            .buttonStyle(SanctuaryButtonStyle())
            .disabled(!store.isStartButtonEnabled)
            .keyboardShortcut(.return, modifiers: .command)

            // Progress indicator
            Text("\(store.checklistItems.filter { $0.on }.count) of \(store.checklistItems.count) completed")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .opacity(store.checklistItems.filter { $0.on }.count > 0 ? 1 : 0)

            // Operation error
            OperationErrorView(error: store.operationError)
        }
        .padding(.top, .momentumButtonSectionTopPadding)
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
