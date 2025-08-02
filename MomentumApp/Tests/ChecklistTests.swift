import ComposableArchitecture
import Foundation
import Sharing
import Testing

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

        $sessionData.withLock { $0 = nil }
        $lastGoal.withLock { $0 = "" }
        $lastTimeMinutes.withLock { $0 = "30" }
        $analysisHistory.withLock { $0 = [] }
    }

    @Test("Checklist Loading - Loads From Rust CLI")
    func checklistLoading() async {
        let mockChecklist = ChecklistState(items: [
            ChecklistItem(id: "0", text: "Rested", on: false),
            ChecklistItem(id: "1", text: "Not hungry", on: false),
            ChecklistItem(id: "2", text: "Bathroom break", on: false),
            ChecklistItem(id: "3", text: "Phone on silent", on: false),
        ])

        let store = TestStore(initialState: PreparationFeature.State()) {
            PreparationFeature()
        } withDependencies: {
            $0.rustCoreClient.checkList = {
                mockChecklist
            }
        }

        // Load checklist on appear - onAppear triggers loadChecklist
        await store.send(.onAppear)
        await store.receive(.loadChecklist) {
            $0.isLoadingChecklist = true
        }
        await store.receive(.checklistResponse(.success(mockChecklist))) {
            $0.isLoadingChecklist = false
            $0.checklistItems = mockChecklist.items
            // Fill slots with first 4 unchecked items
            let uncheckedItems = mockChecklist.items.filter { !$0.on }
            for (index, item) in uncheckedItems.prefix(4).enumerated() {
                $0.checklistSlots[index].item = item
            }
        }
    }

    @Test("Checklist Item Toggle")
    func checklistItemToggle() async {
        let initialChecklist = ChecklistState(items: [
            ChecklistItem(id: "0", text: "Rested", on: false),
            ChecklistItem(id: "1", text: "Not hungry", on: false),
            ChecklistItem(id: "2", text: "Bathroom break", on: false),
            ChecklistItem(id: "3", text: "Phone on silent", on: false),
        ])

        let toggledChecklist = ChecklistState(items: [
            ChecklistItem(id: "0", text: "Rested", on: true),  // toggled
            ChecklistItem(id: "1", text: "Not hungry", on: false),
            ChecklistItem(id: "2", text: "Bathroom break", on: false),
            ChecklistItem(id: "3", text: "Phone on silent", on: false),
        ])

        var initialState = PreparationFeature.State(
            goal: "Test Goal",
            timeInput: "30"
        )
        initialState.checklistItems = initialChecklist.items

        let store = TestStore(
            initialState: initialState
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.rustCoreClient.checkToggle = { id in
                #expect(id == "0")
                return toggledChecklist
            }
        }

        // Toggle first item
        await store.send(.checklistItemToggled(id: "0"))
        await store.receive(.checklistToggleResponse(slotId: -1, .success(toggledChecklist))) {
            $0.checklistItems = toggledChecklist.items
        }
    }

    @Test("Start Button Enabled Logic - Requires All Items Checked")
    func startButtonEnabledLogic() async {
        // Test with empty state
        var state = PreparationFeature.State()
        #expect(!state.isStartButtonEnabled)

        // Add goal
        state.goal = "Test Goal"
        #expect(!state.isStartButtonEnabled)

        // Add valid time
        state.timeInput = "30"
        #expect(!state.isStartButtonEnabled)  // Still need all items checked

        // Add checklist with 5 items with some unchecked
        state.checklistItems = [
            ChecklistItem(id: "0", text: "Rested", on: true),
            ChecklistItem(id: "1", text: "Not hungry", on: false),
            ChecklistItem(id: "2", text: "Bathroom break", on: true),
            ChecklistItem(id: "3", text: "Phone on silent", on: true),
            ChecklistItem(id: "4", text: "Water prepared", on: false),
        ]
        #expect(!state.isStartButtonEnabled)

        // Check all items
        state.checklistItems = state.checklistItems.map { item in
            ChecklistItem(id: item.id, text: item.text, on: true)
        }
        #expect(state.isStartButtonEnabled)

        // Test invalid time inputs
        state.timeInput = "0"
        #expect(!state.isStartButtonEnabled)

        state.timeInput = "-5"
        #expect(!state.isStartButtonEnabled)

        state.timeInput = "abc"
        #expect(!state.isStartButtonEnabled)
    }

    @Test("Complete All Checklist Items")
    func completeAllChecklistItems() async {
        // Create checklist with 5 items
        let uncheckedItems = [
            ChecklistItem(id: "0", text: "Rested", on: false),
            ChecklistItem(id: "1", text: "Not hungry", on: false),
            ChecklistItem(id: "2", text: "Bathroom break", on: false),
            ChecklistItem(id: "3", text: "Phone on silent", on: false),
            ChecklistItem(id: "4", text: "Water prepared", on: false),
        ]

        _ = uncheckedItems.map { item in
            ChecklistItem(id: item.id, text: item.text, on: true)
        }

        var initialState = PreparationFeature.State(
            goal: "Test Goal",
            timeInput: "30"
        )
        initialState.checklistItems = uncheckedItems

        let store = TestStore(
            initialState: initialState
        ) {
            PreparationFeature()
        } withDependencies: {
            let currentItems = LockIsolated(uncheckedItems)
            $0.rustCoreClient.checkToggle = { id in
                // Toggle the specific item
                currentItems.withValue { items in
                    items = items.map { item in
                        if item.id == id {
                            return ChecklistItem(id: item.id, text: item.text, on: true)
                        }
                        return item
                    }
                }
                return ChecklistState(items: currentItems.value)
            }
        }

        // Initially, start button should be disabled
        #expect(!store.state.isStartButtonEnabled)

        // Toggle each item one by one
        for i in 0..<5 {
            let itemId = String(i)
            await store.send(.checklistItemToggled(id: itemId))

            // Receive the updated checklist
            let expectedItems = uncheckedItems.enumerated().map { index, item in
                ChecklistItem(id: item.id, text: item.text, on: index <= i)
            }
            await store.receive(.checklistToggleResponse(slotId: -1, .success(ChecklistState(items: expectedItems)))) {
                $0.checklistItems = expectedItems
            }
        }

        // After all items are checked, start button should be enabled
        #expect(store.state.isStartButtonEnabled)
    }

    @Test("Goal and Time Input Updates")
    func goalAndTimeInputUpdates() async {
        let store = TestStore(initialState: PreparationFeature.State()) {
            PreparationFeature()
        }

        // Test goal update
        await store.send(.goalChanged("New Goal")) {
            $0.goal = "New Goal"
        }

        // Test time input update
        await store.send(.timeInputChanged("45")) {
            $0.timeInput = "45"
        }
    }

    @Test("Goal Validation - Invalid Characters")
    func goalValidationInvalidCharacters() async {
        var state = PreparationFeature.State()
        // Set all checklist items as checked
        state.checklistItems = (0..<5).map { i in
            ChecklistItem(id: String(i), text: "Item \(i)", on: true)
        }
        state.timeInput = "30"

        // Test various invalid characters
        let invalidGoals = [
            "Test/Goal",
            "Test:Goal",
            "Test*Goal",
            "Test?Goal",
            "Test\"Goal",
            "Test<Goal>",
            "Test|Goal",
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
        // Set all checklist items as checked
        state.checklistItems = (0..<5).map { i in
            ChecklistItem(id: String(i), text: "Item \(i)", on: true)
        }
        state.timeInput = "30"

        // Test valid goals
        let validGoals = [
            "Test Goal",
            "Implement new feature",
            "Fix bug 123",
            "test_goal-123",
            "UPPERCASE GOAL",
            "Goal with numbers 456",
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
        // Set all checklist items as checked
        state.checklistItems = (0..<5).map { i in
            ChecklistItem(id: String(i), text: "Item \(i)", on: true)
        }
        state.timeInput = "30"
        state.goal = "Invalid/Goal"

        #expect(state.isStartButtonEnabled == false)
        #expect(state.goalValidationError == "Goal contains invalid characters. Please avoid: / : * ? \" < > |")
    }

    @Test("Rapid Clicking Race Condition Prevention")
    func rapidClickingRaceConditionPrevention() async {
        // Create a larger checklist to ensure we have enough items for testing
        let fullChecklist = (0..<10).map { i in
            ChecklistItem(id: String(i), text: "Item \(i)", on: false)
        }

        var initialState = PreparationFeature.State()
        initialState.checklistItems = fullChecklist
        // Fill slots with first 4 items
        initialState.checklistSlots = (0..<4).map { i in
            var slot = PreparationFeature.ChecklistSlot(id: i)
            slot.item = fullChecklist[i]
            return slot
        }

        let store = TestStore(initialState: initialState) {
            PreparationFeature()
        } withDependencies: {
            // Mock the clock for deterministic timing
            $0.continuousClock = ImmediateClock()
            let checkedItems = LockIsolated<Set<String>>([])
            
            $0.rustCoreClient.checkToggle = { id in
                // Simulate successful toggle
                _ = checkedItems.withValue { $0.insert(id) }
                return checkedItems.withValue { checkedSet in
                    let updatedItems = fullChecklist.map { item in
                        ChecklistItem(
                            id: item.id,
                            text: item.text,
                            on: checkedSet.contains(item.id)
                        )
                    }
                    return ChecklistState(items: updatedItems)
                }
            }
        }

        // Test rapid clicking of first two slots (items "0" and "1")
        // This should trigger the race condition prevention logic
        
        // Click first slot - should work and immediately update state
        await store.send(.checklistSlotToggled(slotId: 0)) {
            // Immediate optimistic update
            $0.checklistItems[0] = ChecklistItem(id: "0", text: "Item 0", on: true)
            $0.checklistSlots[0].item = ChecklistItem(id: "0", text: "Item 0", on: true)
        }
        await store.receive(.checklistItemToggled(id: "0"))

        // Click second slot rapidly - should also work
        await store.send(.checklistSlotToggled(slotId: 1)) {
            // Immediate optimistic update
            $0.checklistItems[1] = ChecklistItem(id: "1", text: "Item 1", on: true)
            $0.checklistSlots[1].item = ChecklistItem(id: "1", text: "Item 1", on: true)
        }
        await store.receive(.checklistItemToggled(id: "1"))

        // Try to click the same slot again - should be ignored due to item already being checked
        await store.send(.checklistSlotToggled(slotId: 0))
        // No effects should be received since the item is already checked

        // Receive the Rust responses
        let firstResponse = ChecklistState(items: fullChecklist.map { item in
            ChecklistItem(id: item.id, text: item.text, on: item.id == "0")
        })
        await store.receive(.checklistToggleResponse(slotId: 0, .success(firstResponse))) {
            $0.checklistItems = firstResponse.items
            $0.checklistSlots[0].item = firstResponse.items[0]
            // Item "4" should be reserved for this slot's transition
            $0.reservedItemIds.insert("4")
        }

        let secondResponse = ChecklistState(items: fullChecklist.map { item in
            ChecklistItem(id: item.id, text: item.text, on: item.id == "0" || item.id == "1")
        })
        await store.receive(.checklistToggleResponse(slotId: 1, .success(secondResponse))) {
            $0.checklistItems = secondResponse.items
            $0.checklistSlots[1].item = secondResponse.items[1]
            // Item "5" should be reserved (item "4" is already reserved)
            $0.reservedItemIds.insert("5")
        }

        // Both slots should start their transitions with different replacement items
        await store.receive(.beginSlotTransition(slotId: 0, replacementItemId: "4")) {
            $0.checklistSlots[0].isTransitioning = true
            $0.activeTransitions[0] = PreparationFeature.ItemTransition(
                slotId: 0,
                replacementItemId: "4",
                startTime: Date(timeIntervalSince1970: 0)
            )
        }
        
        await store.receive(.beginSlotTransition(slotId: 1, replacementItemId: "5")) {
            $0.checklistSlots[1].isTransitioning = true
            $0.activeTransitions[1] = PreparationFeature.ItemTransition(
                slotId: 1,
                replacementItemId: "5",
                startTime: Date(timeIntervalSince1970: 0)
            )
        }

        // Verify no duplicate items were assigned
        let assignedItems = store.state.activeTransitions.values.compactMap { $0.replacementItemId }
        #expect(Set(assignedItems).count == assignedItems.count, "No duplicate items should be assigned")
        
        // Complete the transitions
        await store.receive(.completeSlotTransition(slotId: 0)) {
            $0.checklistSlots[0].item = nil
            $0.checklistSlots[0].isTransitioning = false
            $0.checklistSlots[0].isFadingIn = false
            $0.activeTransitions.removeValue(forKey: 0)
        }
        
        await store.receive(.completeSlotTransition(slotId: 1)) {
            $0.checklistSlots[1].item = nil
            $0.checklistSlots[1].isTransitioning = false
            $0.checklistSlots[1].isFadingIn = false
            $0.activeTransitions.removeValue(forKey: 1)
        }

        // Fade in new items
        await store.receive(.fadeInNewItem(slotId: 0, itemId: "4")) {
            $0.checklistSlots[0].item = ChecklistItem(id: "4", text: "Item 4", on: false)
            $0.checklistSlots[0].isFadingIn = true
            $0.reservedItemIds.remove("4")  // Reservation cleaned up
        }
        
        await store.receive(.fadeInNewItem(slotId: 1, itemId: "5")) {
            $0.checklistSlots[1].item = ChecklistItem(id: "5", text: "Item 5", on: false)
            $0.checklistSlots[1].isFadingIn = true
            $0.reservedItemIds.remove("5")  // Reservation cleaned up
        }

        // Complete fade-ins
        await store.receive(.resetFadeInFlag(slotId: 0)) {
            $0.checklistSlots[0].isFadingIn = false
        }
        
        await store.receive(.resetFadeInFlag(slotId: 1)) {
            $0.checklistSlots[1].isFadingIn = false
        }

        // Verify final state: no reservations, different items in slots
        #expect(store.state.reservedItemIds.isEmpty)
        #expect(store.state.checklistSlots[0].item?.id == "4")
        #expect(store.state.checklistSlots[1].item?.id == "5")
        #expect(store.state.checklistSlots[0].item?.id != store.state.checklistSlots[1].item?.id)
    }
}
