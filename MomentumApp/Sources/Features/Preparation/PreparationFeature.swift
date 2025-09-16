import ComposableArchitecture
import Foundation
import OSLog
import Sharing

@Reducer
struct PreparationFeature {
    private static let logger = Logger(subsystem: "com.bkase.MomentumApp", category: "PreparationFeature")
    @ObservableState
    struct State: Equatable {
        var goal: String = ""
        var timeInput: String = ""
        var checklistItems: [ChecklistItem] = []  // Full list from Rust CLI
        var checklistSlots: [ChecklistSlot] = []  // 4 visible slots
        var activeTransitions: [Int: ItemTransition] = [:]
        var reservedItemIds: Set<String> = []  // Items reserved for upcoming transitions
        var isLoadingChecklist: Bool = false
        var operationError: String?

        var goalValidationError: String? {
            // Only allow A-Z, a-z, 0-9, and space
            let allowedCharacters = CharacterSet(
                charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ")
            let goalCharacterSet = CharacterSet(charactersIn: goal)

            if !allowedCharacters.isSuperset(of: goalCharacterSet) {
                return "Goal can only contain letters, numbers, and spaces"
            }
            return nil
        }

        var isStartButtonEnabled: Bool {
            !goal.isEmpty && Int(timeInput).map { $0 > 0 } == true && checklistItems.count >= 5  // Ensure we have the full checklist
                && checklistItems.allSatisfy { $0.on } && goalValidationError == nil
        }

        init(
            goal: String = "",
            timeInput: String = ""
        ) {
            self.goal = goal
            self.timeInput = timeInput
            self.checklistSlots = Self.createInitialSlots()
        }

        static func createInitialSlots() -> [ChecklistSlot] {
            (0..<4).map { ChecklistSlot(id: $0) }
        }

        init(preparationState: PreparationState) {
            self.goal = preparationState.goal
            self.timeInput = preparationState.timeInput
        }

        var preparationState: PreparationState {
            PreparationState(
                goal: goal,
                timeInput: timeInput,
                checklist: IdentifiedArray(uniqueElements: [])  // No longer used
            )
        }
    }

    enum Action: Equatable {
        case onAppear
        case loadChecklist
        case checklistResponse(TaskResult<ChecklistState>)
        case checklistSlotToggled(slotId: Int)
        case checklistItemToggled(id: String)
        case checklistToggleResponse(slotId: Int, TaskResult<ChecklistState>)
        case beginSlotTransition(slotId: Int, replacementItemId: String?)
        case completeSlotTransition(slotId: Int)
        case fadeInNewItem(slotId: Int, itemId: String)
        case resetFadeInFlag(slotId: Int)
        case goalChanged(String)
        case timeInputChanged(String)
        case startButtonTapped
        case startSessionResponse(TaskResult<SessionData>)
        case clearOperationError
        case delegate(Delegate)

        enum Delegate: Equatable {
            case sessionStarted(SessionData)
            case sessionFailedToStart(AppError)
        }
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.a4Client) var a4Client

    enum CancelID { case errorDismissal }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.loadChecklist)
                }

            case .loadChecklist:
                state.isLoadingChecklist = true
                return .run { send in
                    await send(
                        .checklistResponse(
                            TaskResult {
                                try await a4Client.checkList()
                            }
                        )
                    )
                }

            case let .checklistResponse(.success(checklistState)):
                state.isLoadingChecklist = false
                state.checklistItems = checklistState.items

                // Fill slots with first 4 unchecked items
                let uncheckedItems = checklistState.items.filter { !$0.on }
                var slots = state.checklistSlots
                for (index, item) in uncheckedItems.prefix(4).enumerated() {
                    slots[index].item = item
                }
                state.checklistSlots = slots

                return .none

            case let .checklistResponse(.failure(error)):
                state.isLoadingChecklist = false
                state.operationError = "Failed to load checklist: \(error.localizedDescription)"
                Self.logger.error("Failed to load checklist: \(error)")
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.clearOperationError)
                }
                .cancellable(id: CancelID.errorDismissal)

            case let .checklistSlotToggled(slotId):
                // Immediate optimistic update to prevent racing conditions
                guard slotId < state.checklistSlots.count,
                    let item = state.checklistSlots[slotId].item,
                    !state.checklistSlots[slotId].isTransitioning  // Prevent duplicate clicks while transitioning
                else { return .none }

                // Optimistically mark the item as checked in local state
                var updatedItems = state.checklistItems
                if let itemIndex = updatedItems.firstIndex(where: { $0.id == item.id }) {
                    updatedItems[itemIndex] = ChecklistItem(
                        id: item.id,
                        text: item.text,
                        on: true
                    )
                    state.checklistItems = updatedItems

                    // Update the slot's item to reflect the checked state
                    var slots = state.checklistSlots
                    slots[slotId].item = updatedItems[itemIndex]
                    state.checklistSlots = slots
                }

                return Self.handleChecklistSlotToggled(
                    state: &state,
                    slotId: slotId,
                    clock: clock
                )

            case let .checklistItemToggled(id):
                // Find which slot this item is in
                let slotId = state.checklistSlots.firstIndex { $0.item?.id == id } ?? -1

                return .run { send in
                    let result = await TaskResult {
                        try await a4Client.checkToggle(id)
                    }
                    await send(.checklistToggleResponse(slotId: slotId, result))
                }

            case let .checklistToggleResponse(slotId, .success(checklistState)):
                if slotId >= 0 {
                    return Self.handleChecklistToggleSuccess(
                        state: &state,
                        slotId: slotId,
                        updatedItems: checklistState.items,
                        clock: clock
                    )
                } else {
                    // Just update the items if we don't know the slot
                    state.checklistItems = checklistState.items
                    return .none
                }

            case let .checklistToggleResponse(_, .failure(error)):
                state.operationError = "Failed to toggle checklist item: \(error.localizedDescription)"
                Self.logger.error("Failed to toggle checklist item: \(error)")
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.clearOperationError)
                }
                .cancellable(id: CancelID.errorDismissal)

            case let .beginSlotTransition(slotId, replacementItemId):
                return Self.handleBeginSlotTransition(
                    state: &state,
                    slotId: slotId,
                    replacementItemId: replacementItemId,
                    clock: clock
                )

            case let .completeSlotTransition(slotId):
                return Self.handleCompleteSlotTransition(
                    state: &state,
                    slotId: slotId,
                    clock: clock
                )

            case let .fadeInNewItem(slotId, itemId):
                return Self.handleFadeInNewItem(
                    state: &state,
                    slotId: slotId,
                    itemId: itemId,
                    clock: clock
                )

            case let .resetFadeInFlag(slotId):
                var slots = state.checklistSlots
                slots[slotId].isFadingIn = false
                state.checklistSlots = slots
                return .none

            case let .goalChanged(newGoal):
                // Filter input to only allow letters, numbers, and spaces
                let allowedCharacters = CharacterSet(
                    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ")
                let filtered = newGoal.unicodeScalars.filter { allowedCharacters.contains($0) }
                state.goal = String(String.UnicodeScalarView(filtered))
                // Clear operation error when user types
                state.operationError = nil
                return .none

            case let .timeInputChanged(newTime):
                state.timeInput = newTime
                // Clear operation error when user types
                state.operationError = nil
                return .none

            case .startButtonTapped:
                // Clear any previous errors
                state.operationError = nil

                // Validate inputs
                guard let minutes = UInt64(state.timeInput), minutes > 0 else {
                    let error = "Please enter a valid time in minutes"
                    state.operationError = error
                    Self.logger.error("Start button validation failed: \(error)")
                    return .none
                }

                guard !state.goal.isEmpty else {
                    let error = "Please enter a goal"
                    state.operationError = error
                    Self.logger.error("Start button validation failed: \(error)")
                    return .none
                }

                // Start the session
                return .run { [goal = state.goal] send in
                    await send(
                        .startSessionResponse(
                            TaskResult {
                                try await a4Client.start(goal, Int(minutes))
                            }
                        )
                    )
                }

            case let .startSessionResponse(.success(sessionData)):
                return .send(.delegate(.sessionStarted(sessionData)))

            case let .startSessionResponse(.failure(error)):
                if let rustError = error as? RustCoreError {
                    state.operationError = rustError.errorDescription ?? "An error occurred"
                    Self.logger.error("Failed to start session - RustCoreError: \(String(describing: rustError))")
                } else {
                    state.operationError = error.localizedDescription
                    Self.logger.error("Failed to start session: \(error.localizedDescription)")
                }
                // Auto-dismiss operation error after 5 seconds
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.clearOperationError)
                }
                .cancellable(id: CancelID.errorDismissal)

            case .clearOperationError:
                state.operationError = nil
                return .none

            case .delegate:
                // Delegate actions are handled by parent
                return .none
            }
        }
    }
}
