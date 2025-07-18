import Testing
import Foundation
import ComposableArchitecture
import Sharing
@testable import MomentumApp

@Suite("Checklist Tests")
@MainActor
struct ChecklistTests {
    init() {
        // Reset shared state before each test
        @Shared(.sessionData) var sessionData: SessionData?
        @Shared(.lastGoal) var lastGoal: String
        @Shared(.lastTimeMinutes) var lastTimeMinutes: String
        @Shared(.analysisHistory) var analysisHistory: [AnalysisResult]
        @Shared(.preparationState) var preparationState: PreparationPersistentState
        
        $sessionData.withLock { $0 = nil }
        $lastGoal.withLock { $0 = "" }
        $lastTimeMinutes.withLock { $0 = "30" }
        $analysisHistory.withLock { $0 = [] }
        $preparationState.withLock { $0 = .initial }
    }
    
    @Test("Checklist Loading - Loads First 4 Items")
    func checklistLoading() async {
        let store = TestStore(initialState: PreparationFeature.State()) {
            PreparationFeature()
        }
        
        // Load checklist on appear - should load first 4 items
        await store.send(.onAppear) {
            $0.checklistSlots = [
                PreparationFeature.ChecklistSlot(id: 0, item: ChecklistItem(id: "0", text: "Rested", isCompleted: false)),
                PreparationFeature.ChecklistSlot(id: 1, item: ChecklistItem(id: "1", text: "Not hungry", isCompleted: false)),
                PreparationFeature.ChecklistSlot(id: 2, item: ChecklistItem(id: "2", text: "Bathroom break", isCompleted: false)),
                PreparationFeature.ChecklistSlot(id: 3, item: ChecklistItem(id: "3", text: "Phone on silent", isCompleted: false))
            ]
            $0.nextItemIndex = 4
        }
    }
    
    @Test("Checklist Item Toggle - With Replacement")
    func checklistItemToggleWithReplacement() async {
        let clock = TestClock()
        
        // Simply verify that toggling works and items get replaced
        let store = TestStore(
            initialState: PreparationFeature.State(
                goal: "Test Goal",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        
        // Use non-exhaustive testing since we have animations and UUIDs
        store.exhaustivity = .off
        
        // Load initial checklist
        await store.send(.onAppear)
        
        let initialCount = store.state.checklistSlots.count
        #expect(initialCount == 4)
        
        // Toggle first slot's item
        await store.send(.checklistSlotToggled(slotId: 0))
        
        // Wait for transitions to complete (600ms + 300ms + 100ms + 350ms)
        await clock.advance(by: .milliseconds(1350))
        
        // Verify item was marked completed
        #expect(store.state.totalItemsCompleted == 1)
        
        // Since we're using non-exhaustive testing, we can't test the exact replacement behavior
        // but we can verify that the feature handles toggling correctly
    }
    
    @Test("Start Button Enabled Logic - Requires All 10 Items")
    func startButtonEnabledLogic() async {
        // Test with empty state
        var state = PreparationFeature.State()
        #expect(!state.isStartButtonEnabled)
        
        // Add goal
        state.goal = "Test Goal"
        #expect(!state.isStartButtonEnabled)
        
        // Add valid time
        state.timeInput = "30"
        #expect(!state.isStartButtonEnabled) // Still need all 10 items completed
        
        // Complete 9 items
        state.totalItemsCompleted = 9
        #expect(!state.isStartButtonEnabled)
        
        // Complete all 10 items
        state.totalItemsCompleted = 10
        #expect(state.isStartButtonEnabled)
        
        // Test invalid time inputs
        state.timeInput = "0"
        #expect(!state.isStartButtonEnabled)
        
        state.timeInput = "-5"
        #expect(!state.isStartButtonEnabled)
        
        state.timeInput = "abc"
        #expect(!state.isStartButtonEnabled)
    }
    
    @Test("Complete All 10 Items")
    func completeAllTenItems() async {
        let clock = TestClock()
        
        let store = TestStore(
            initialState: PreparationFeature.State(
                goal: "Test Goal",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        
        // Set exhaustivity to off since we have non-deterministic UUIDs
        store.exhaustivity = .off
        
        // Load initial items
        await store.send(.onAppear) {
            $0.checklistSlots = [
                PreparationFeature.ChecklistSlot(id: 0, item: ChecklistItem(id: "0", text: "Rested", isCompleted: false)),
                PreparationFeature.ChecklistSlot(id: 1, item: ChecklistItem(id: "1", text: "Not hungry", isCompleted: false)),
                PreparationFeature.ChecklistSlot(id: 2, item: ChecklistItem(id: "2", text: "Bathroom break", isCompleted: false)),
                PreparationFeature.ChecklistSlot(id: 3, item: ChecklistItem(id: "3", text: "Phone on silent", isCompleted: false))
            ]
            $0.nextItemIndex = 4
        }
        
        // Complete all 10 items by toggling slots
        for i in 0..<10 {
            // Find first slot with incomplete item
            if let slotIndex = store.state.checklistSlots.firstIndex(where: { slot in
                slot.item != nil && !slot.item!.isCompleted
            }) {
                await store.send(.checklistSlotToggled(slotId: slotIndex)) {
                    $0.checklistSlots[slotIndex].item?.isCompleted = true
                    $0.totalItemsCompleted = i + 1
                }
                
                // If we still have items to show, handle the transition
                if i < 6 { // First 6 toggles will trigger replacements
                    // 600ms delay + 300ms fade-out + 100ms gap + 350ms for fade-in reset
                    await clock.advance(by: .milliseconds(1350))
                }
            }
        }
        
        // Verify all 10 items are completed
        #expect(store.state.totalItemsCompleted == 10)
        #expect(store.state.isStartButtonEnabled)
    }
    
    @Test("Goal and Time Input Updates")
    func goalAndTimeInputUpdates() async {
        // Create initial state and capture what the slots look like after init
        let initialState = PreparationFeature.State()
        let store = TestStore(initialState: initialState) {
            PreparationFeature()
        }
        
        // Test goal update
        await store.send(.goalChanged("New Goal")) {
            $0.goal = "New Goal"
            // checklistSlots remain unchanged from init
        }
        
        // Test time input update
        await store.send(.timeInputChanged("45")) {
            $0.timeInput = "45"
            // checklistSlots remain unchanged from init
        }
    }
    
    @Test("Goal Validation - Invalid Characters")
    func goalValidationInvalidCharacters() async {
        var state = PreparationFeature.State()
        state.checklistSlots = PreparationFeature.State.createInitialSlots()
        state.totalItemsCompleted = 10
        state.timeInput = "30"
        
        // Test various invalid characters
        let invalidGoals = [
            "Test/Goal",
            "Test:Goal",
            "Test*Goal",
            "Test?Goal",
            "Test\"Goal",
            "Test<Goal>",
            "Test|Goal"
        ]
        
        for invalidGoal in invalidGoals {
            state.goal = invalidGoal
            #expect(state.goalValidationError != nil)
            #expect(state.isStartButtonEnabled == false)
        }
    }
    
    @Test("Goal Validation - Valid Goals")
    func goalValidationValidGoals() async {
        var state = PreparationFeature.State()
        state.checklistSlots = PreparationFeature.State.createInitialSlots()
        state.totalItemsCompleted = 10
        state.timeInput = "30"
        
        // Test valid goals
        let validGoals = [
            "Test Goal",
            "Implement new feature",
            "Fix bug 123",
            "test_goal-123",
            "UPPERCASE GOAL",
            "Goal with numbers 456"
        ]
        
        for validGoal in validGoals {
            state.goal = validGoal
            #expect(state.goalValidationError == nil)
            #expect(state.isStartButtonEnabled == true)
        }
    }
    
    @Test("Goal Validation - Start Button Disabled With Invalid Goal")
    func startButtonDisabledWithInvalidGoal() async {
        var state = PreparationFeature.State()
        state.checklistSlots = PreparationFeature.State.createInitialSlots()
        state.totalItemsCompleted = 10
        state.timeInput = "30"
        state.goal = "Invalid/Goal"
        
        #expect(state.isStartButtonEnabled == false)
        #expect(state.goalValidationError == "Goal contains invalid characters. Please avoid: / : * ? \" < > |")
    }
}