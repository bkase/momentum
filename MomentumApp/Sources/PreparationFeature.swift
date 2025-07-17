import ComposableArchitecture
import Foundation
import Sharing

@Reducer
struct PreparationFeature {
    @ObservableState
    struct State: Equatable {
        var goal: String = ""
        var timeInput: String = ""
        @Shared(.preparationState) var persistentState = PreparationPersistentState.initial
        var activeTransitions: [Int: ItemTransition] = [:] // Key is slot ID
        
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
        
        var isStartButtonEnabled: Bool {
            !goal.isEmpty &&
            Int(timeInput).map { $0 > 0 } == true &&
            totalItemsCompleted == 10
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
    }
    
    @Dependency(\.checklistClient) var checklistClient
    @Dependency(\.continuousClock) var clock
    
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
                return .none
                
            case let .timeInputChanged(newTime):
                state.timeInput = newTime
                return .none
                
            case .startButtonTapped:
                // This will be handled by parent
                return .none
            }
        }
    }
}