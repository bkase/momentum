import Testing
import Foundation
import ComposableArchitecture
@testable import MomentumApp

@Suite("Full Flow Tests")
@MainActor
struct FullFlowTests {
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
    
    @Test("Full Flow")
    func fullFlow() async {
        let fixedTime: UInt64 = 1700000000
        
        // Set up initial shared state with the values we want
        @Shared(.lastGoal) var lastGoal: String
        @Shared(.lastTimeMinutes) var lastTimeMinutes: String
        @Shared(.analysisHistory) var analysisHistory: [AnalysisResult]
        $lastGoal.withLock { $0 = "Full Flow Test" }
        $lastTimeMinutes.withLock { $0 = "20" }
        $analysisHistory.withLock { $0 = [] }  // Ensure empty history
        
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.rustCoreClient.start = { goal, minutes in
                SessionData(
                    goal: goal,
                    startTime: fixedTime,
                    timeExpected: UInt64(minutes),  // timeExpected is in minutes
                    reflectionFilePath: nil
                )
            }
            $0.rustCoreClient.stop = {
                "/tmp/test-reflection.md"
            }
            $0.rustCoreClient.analyze = { _ in
                AnalysisResult(
                    summary: "Test analysis summary",
                    suggestion: "Test suggestion",
                    reasoning: "Test reasoning"
                )
            }
            $0.checklistClient = .testValue
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
        
        // Since we can't complete all 10 items easily in the test, 
        // let's test the flow by simulating the delegate from PreparationFeature
        // 1. Start session via delegate
        let sessionData = SessionData(
            goal: "Full Flow Test",
            startTime: fixedTime,
            timeExpected: 20,  // 20 minutes
            reflectionFilePath: nil
        )
        
        await store.send(.destination(.presented(.preparation(.delegate(.sessionStarted(sessionData)))))) {
            $0.isLoading = false
            // Don't manually update shared state - the reducer handles it
            $0.reflectionPath = nil
            $0.destination = .activeSession(ActiveSessionFeature.State(
                goal: "Full Flow Test",
                startTime: Date(timeIntervalSince1970: TimeInterval(fixedTime)),
                expectedMinutes: 20
            ))
        }
        
        // 2. Stop session immediately
        await store.send(.destination(.presented(.activeSession(.stopButtonTapped)))) {
            $0.isLoading = true
        }
        
        // Forward the performStop action to ActiveSessionFeature
        await store.receive(.destination(.presented(.activeSession(.performStop))))
        
        // Receive delegate response from ActiveSessionFeature
        await store.receive(.destination(.presented(.activeSession(.delegate(.sessionStopped(reflectionPath: "/tmp/test-reflection.md")))))) {
            $0.isLoading = false
            // Don't manually update shared state - the reducer handles it
            $0.reflectionPath = "/tmp/test-reflection.md"
            $0.destination = .reflection(ReflectionFeature.State(reflectionPath: "/tmp/test-reflection.md"))
        }
        
        // 3. Analyze reflection
        await store.send(.destination(.presented(.reflection(.analyzeButtonTapped)))) {
            $0.isLoading = true
        }
        
        await store.receive(.destination(.presented(.reflection(.delegate(.analysisRequested(analysisResult: AnalysisResult(
            summary: "Test analysis summary",
            suggestion: "Test suggestion",
            reasoning: "Test reasoning"
        ))))))) {
            $0.isLoading = false
            $0.reflectionPath = nil
            // The reducer automatically appends to analysisHistory, so we don't do it here
            $0.destination = .analysis(AnalysisFeature.State(analysis: AnalysisResult(
                summary: "Test analysis summary",
                suggestion: "Test suggestion",
                reasoning: "Test reasoning"
            )))
        }
        
        // 4. Reset to preparing immediately
        await store.send(.destination(.presented(.analysis(.resetButtonTapped))))
        
        await store.receive(.resetToIdle) {
            // Don't manually update shared state - the reducer handles it
            $0.reflectionPath = nil
            // Clear state
            $0.isLoading = false
            $0.destination = .preparation(PreparationFeature.State(
                goal: "Full Flow Test",
                timeInput: "20"
            ))
        }
    }
}