import Testing
import Foundation
import ComposableArchitecture
@testable import MomentumApp

@Suite("Error Handling Tests")
@MainActor
struct ErrorHandlingTests {
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
    
    @Test("Error Handling")
    func errorHandling() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        store.exhaustivity = .off
                
        // Test that delegate error is handled
        let error = AppError.rustCore(.binaryNotFound)
        await store.send(.destination(.presented(.preparation(.delegate(.sessionFailedToStart(error)))))) {
            $0.isLoading = false
            // Error handled in PreparationFeature
        }
    }
    
    
    @Test("Direct Session Stop")
    func directSessionStop() async {
        var state = AppFeature.State()
        state.destination = .activeSession(ActiveSessionFeature.State(
            goal: "Test Goal",
            startTime: Date(timeIntervalSince1970: 1700000000),
            expectedMinutes: 30
        ))
        
        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        }
        store.exhaustivity = .off
        
        // Stop button triggers stop action
        await store.send(.destination(.presented(.activeSession(.stopButtonTapped)))) {
            $0.isLoading = true
        }
        await store.receive(.destination(.presented(.activeSession(.performStop))))
    }
    
    
    @Test("Cancel Current Operation")
    func cancelCurrentOperation() async {
        let store = TestStore(
            initialState: AppFeature.State.test(
                isLoading: true
            )
        ) {
            AppFeature()
        }
        
                
        await store.send(.cancelCurrentOperation) {
            $0.isLoading = false
        }
    }
}