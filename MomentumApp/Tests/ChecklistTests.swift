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
            $0.a4Client.checkList = {
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
            $0.a4Client.checkToggle = { id in
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
            $0.a4Client.checkToggle = { id in
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

        // Test various invalid characters (anything besides letters, numbers, and spaces)
        let invalidGoals = [
            "Test/Goal",
            "Test:Goal",
            "Test*Goal",
            "Test?Goal",
            "Test\"Goal",
            "Test<Goal>",
            "Test|Goal",
            "Test-Goal",  // hyphen not allowed
            "Test_Goal",  // underscore not allowed
            "Test.Goal",  // period not allowed
            "Test@Goal",  // @ not allowed
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

        // Test valid goals (only letters, numbers, and spaces allowed)
        let validGoals = [
            "Test Goal",
            "Implement new feature",
            "Fix bug 123",
            "test goal 123",
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
        #expect(state.goalValidationError == "Goal can only contain letters, numbers, and spaces")
    }

}
