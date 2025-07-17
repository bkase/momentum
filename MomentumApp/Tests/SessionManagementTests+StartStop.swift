import Testing
import Foundation
import ComposableArchitecture
@testable import MomentumApp

extension SessionManagementTests {
    @Test("Start Session")
    func startSession() async {
        // Set up shared state before creating the store
        @Shared(.lastGoal) var lastGoal: String
        @Shared(.lastTimeMinutes) var lastTimeMinutes: String
        $lastGoal.withLock { $0 = "Test Goal" }
        $lastTimeMinutes.withLock { $0 = "30" }
        
        let store = TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.rustCoreClient.start = { goal, minutes in
                SessionData.mock(
                    goal: goal,
                    startTime: Date(timeIntervalSince1970: 1_700_000_000),
                    timeExpected: UInt64(minutes)  // timeExpected is in minutes
                )
            }
            $0.checklistClient.load = { ChecklistItem.mockItems }
        }
        store.exhaustivity = .off
        
        // Destination already set by init, onAppear should not change anything
        await store.send(.onAppear)
        
        // Load checklist
        await store.send(.destination(.presented(.preparation(.onAppear)))) {
            if case .preparation(var preparationState) = $0.destination {
                // onAppear now directly creates the first 4 items from ChecklistItemPool
                preparationState.checklistSlots = [
                    PreparationFeature.ChecklistSlot(id: 0, item: ChecklistItem(id: "0", text: "Rested", isCompleted: false)),
                    PreparationFeature.ChecklistSlot(id: 1, item: ChecklistItem(id: "1", text: "Not hungry", isCompleted: false)),
                    PreparationFeature.ChecklistSlot(id: 2, item: ChecklistItem(id: "2", text: "Bathroom break", isCompleted: false)),
                    PreparationFeature.ChecklistSlot(id: 3, item: ChecklistItem(id: "3", text: "Phone on silent", isCompleted: false))
                ]
                $0.destination = .preparation(preparationState)
            }
        }
        
        // Start session directly instead of going through the checklist flow
        await store.send(.startSession(goal: "Test Goal", minutes: 30)) {
            $0.isLoading = true
            $0.alert = nil
        }
        
        // The effect executes immediately and sends the response
        let sessionData = SessionData.mock(
            goal: "Test Goal",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            timeExpected: 30  // 30 minutes
        )
        await store.receive(.rustCoreResponse(.success(.sessionStarted(sessionData)))) {
            $0.isLoading = false
            // Don't manually update shared state - the reducer handles it
            $0.reflectionPath = nil
            $0.destination = .activeSession(ActiveSessionFeature.State(
                goal: "Test Goal",
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                expectedMinutes: 30
            ))
        }
    }
    
    @Test("Stop Session")
    func stopSession() async {
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)
        let sessionData = SessionData.mock(
            goal: "Test Goal",
            startTime: startTime,
            timeExpected: 30  // 30 minutes
        )
        
        // Set up shared state before creating the store
        @Shared(.sessionData) var sharedSessionData: SessionData?
        $sharedSessionData.withLock { $0 = sessionData }
        
        let store = TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.rustCoreClient.stop = {
                "/tmp/test-reflection.md"
            }
        }
        store.exhaustivity = .off
        
        // Destination already set by init, onAppear should not change anything
        await store.send(.onAppear)
        
        // Stop session - shows confirmation dialog
        await store.send(.destination(.presented(.activeSession(.stopButtonTapped)))) {
            $0.confirmationDialog = .stopSession()
        }
        
        // Confirm stop
        await store.send(.confirmationDialog(.presented(.confirmStopSession))) {
            $0.confirmationDialog = nil
        }
        
        await store.receive(.stopSession) {
            $0.isLoading = true
            $0.alert = nil
        }
        
        // Receive response
        await store.receive(.rustCoreResponse(.success(.sessionStopped(reflectionPath: "/tmp/test-reflection.md")))) {
            $0.isLoading = false
            // Don't manually update shared state - the reducer handles it
            $0.reflectionPath = "/tmp/test-reflection.md"
            $0.destination = .reflection(ReflectionFeature.State(reflectionPath: "/tmp/test-reflection.md"))
        }
    }
}