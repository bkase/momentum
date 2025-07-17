import Testing
import Foundation
import ComposableArchitecture
@testable import MomentumApp

@Suite("Session Management Tests")
@MainActor
struct SessionManagementTests {
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
    
    @Test("Analyze Reflection")
    func analyzeReflection() async {
        let store = TestStore(
            initialState: AppFeature.State.test(
                reflectionPath: "/tmp/test-reflection.md",
                destination: .reflection(ReflectionFeature.State(reflectionPath: "/tmp/test-reflection.md"))
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.rustCoreClient.analyze = { _ in
                AnalysisResult.mock
            }
        }
        store.exhaustivity = .off
        
        // Analyze reflection
        await store.send(.destination(.presented(.reflection(.analyzeButtonTapped))))
        
        await store.receive(.analyzeReflection(path: "/tmp/test-reflection.md")) {
            $0.isLoading = true
            $0.alert = nil
        }
    }
    
    @Test("Reset to Idle")
    func resetToIdle() async {
        let sessionData = SessionData.mock()
        
        // Set up shared state before creating the store
        @Shared(.sessionData) var sharedSessionData: SessionData?
        @Shared(.analysisHistory) var analysisHistory: [AnalysisResult]
        $sharedSessionData.withLock { $0 = sessionData }
        $analysisHistory.withLock { $0 = [AnalysisResult.mock] }
        
        let store = TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        }
        store.exhaustivity = .off
        
        // Destination already set by init, onAppear should not change anything
        await store.send(.onAppear)
        
        await store.send(.destination(.presented(.analysis(.resetButtonTapped)))) {
            $0.confirmationDialog = .resetToIdle()
        }
        
        // Confirm reset
        await store.send(.confirmationDialog(.presented(.confirmReset))) {
            $0.confirmationDialog = nil
        }
        
        await store.receive(.resetToIdle) {
            // Don't manually update shared state - the reducer handles it
            $0.reflectionPath = nil
            $0.alert = nil
            $0.isLoading = false
            $0.destination = .preparation(PreparationFeature.State(
                goal: "",
                timeInput: "30"
            ))
        }
    }
}