import ComposableArchitecture
import Foundation
import Sharing
import OSLog

@Reducer
struct PreparationFeature {
    private static let logger = Logger(subsystem: "com.bkase.MomentumApp", category: "PreparationFeature")
    @ObservableState
    struct State: Equatable {
        var goal: String = ""
        var timeInput: String = ""
        @Shared(.preparationState) var persistentState = PreparationPersistentState.initial
        var activeTransitions: [Int: ItemTransition] = [:] // Key is slot ID
        var operationError: String?
        
        // Computed properties for accessing persistent state
        var checklistSlots: [ChecklistSlot] {
            get { persistentState.checklistSlots }
            set { $persistentState.withLock { $0.checklistSlots = newValue } }
        }
        
        var totalItemsCompleted: Int {
            get { persistentState.totalItemsCompleted }
            set { $persistentState.withLock { $0.totalItemsCompleted = newValue } }
        }
        
        var nextItemIndex: Int {
            get { persistentState.nextItemIndex }
            set { $persistentState.withLock { $0.nextItemIndex = newValue } }
        }
        
        var goalValidationError: String? {
            let invalidCharacters = CharacterSet(charactersIn: "/:*?\"<>|")
            if goal.rangeOfCharacter(from: invalidCharacters) != nil {
                return "Goal contains invalid characters. Please avoid: / : * ? \" < > |"
            }
            return nil
        }
        
        var isStartButtonEnabled: Bool {
            !goal.isEmpty &&
            Int(timeInput).map { $0 > 0 } == true &&
            totalItemsCompleted == 10 &&
            goalValidationError == nil
        }
        
        init(
            goal: String = "",
            timeInput: String = ""
        ) {
            self.goal = goal
            self.timeInput = timeInput
            // Check if we need to initialize the persistent state
            if self.checklistSlots.isEmpty {
                self.checklistSlots = Self.createInitialSlots()
            }
        }
        
        init(preparationState: PreparationState) {
            self.goal = preparationState.goal
            self.timeInput = preparationState.timeInput
            // Convert old checklist to slots
            var slots = Self.createInitialSlots()
            let items = preparationState.checklist.prefix(4)
            for (index, item) in items.enumerated() {
                slots[index].item = item
            }
            self.checklistSlots = slots
            self.totalItemsCompleted = preparationState.checklist.filter { $0.isCompleted }.count
            self.nextItemIndex = min(4, preparationState.checklist.count)
        }
        
        var preparationState: PreparationState {
            PreparationState(
                goal: goal,
                timeInput: timeInput,
                checklist: IdentifiedArray(uniqueElements: checklistSlots.compactMap { $0.item })
            )
        }
        
        static func createInitialSlots() -> [ChecklistSlot] {
            (0..<4).map { ChecklistSlot(id: $0) }
        }
    }
    
    enum Action: Equatable {
        case onAppear
        case checklistSlotToggled(slotId: Int)
        case beginSlotTransition(slotId: Int, replacementText: String?)
        case completeSlotTransition(slotId: Int)
        case fadeInNewItem(slotId: Int, text: String)
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
    
    @Dependency(\.checklistClient) var checklistClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.rustCoreClient) var rustCoreClient
    
    enum CancelID { case errorDismissal }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case .onAppear:
                // Only initialize if we haven't already (persistent state is empty)
                if state.checklistSlots.isEmpty || state.checklistSlots.allSatisfy({ $0.item == nil }) {
                    // Initialize slots with first 4 items from the pool
                    state.checklistSlots = State.createInitialSlots()
                    let initialItems = ChecklistItemPool.allItems.prefix(4).enumerated().map { index, text in
                        ChecklistItem(id: "\(index)", text: text, isCompleted: false)
                    }
                    var slots = state.checklistSlots
                    for (index, item) in initialItems.enumerated() {
                        slots[index].item = item
                    }
                    state.checklistSlots = slots
                    state.nextItemIndex = 4
                    state.totalItemsCompleted = 0
                }
                return .none
                
            case let .checklistSlotToggled(slotId):
                return Self.handleChecklistSlotToggled(
                    state: &state,
                    slotId: slotId,
                    clock: clock
                )
                
            case let .beginSlotTransition(slotId, replacementText):
                return Self.handleBeginSlotTransition(
                    state: &state,
                    slotId: slotId,
                    replacementText: replacementText,
                    clock: clock
                )
                
            case let .completeSlotTransition(slotId):
                return Self.handleCompleteSlotTransition(
                    state: &state,
                    slotId: slotId,
                    clock: clock
                )
                
            case let .fadeInNewItem(slotId, text):
                return Self.handleFadeInNewItem(
                    state: &state,
                    slotId: slotId,
                    text: text,
                    clock: clock
                )
                
            case let .resetFadeInFlag(slotId):
                // Reset the fade-in flag so the item becomes fully interactive
                var slots = state.checklistSlots
                slots[slotId].isFadingIn = false
                state.checklistSlots = slots
                return .none
                
            case let .goalChanged(newGoal):
                state.goal = newGoal
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
                            await TaskResult {
                                try await rustCoreClient.start(goal, Int(minutes))
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