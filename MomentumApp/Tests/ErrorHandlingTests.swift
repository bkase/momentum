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
    
    @Test("Error Handling via Delegate")
    func errorHandlingViaDelegate() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        store.exhaustivity = .off
                
        // Test error handling via delegate from PreparationFeature
        let error = AppError.rustCore(.binaryNotFound)
        await store.send(.destination(.presented(.preparation(.delegate(.sessionFailedToStart(error)))))) {
            $0.isLoading = false
            $0.alert = .error(error)
        }
    }
    
    
    @Test("Dismiss Alert")
    func dismissAlert() async {
        var state = AppFeature.State()
        state.alert = .genericError(AppError.other("Test Error"))
        
        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        }
        
                
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
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