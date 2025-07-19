import ComposableArchitecture
import Foundation
import Dependencies
@testable import MomentumApp

// MARK: - Test Helpers for Shared State

extension AppFeature.State {
    /// Creates a test state with optional initial values
    static func test(
        sessionData: SessionData? = nil,
        lastGoal: String = "",
        lastTimeMinutes: String = "30",
        analysisHistory: [AnalysisResult] = [],
        reflectionPath: String? = nil,
        isLoading: Bool = false,
        destination: AppFeature.Destination.State? = nil
    ) -> Self {
        // First reset all shared state to ensure clean state
        @Shared(.sessionData) var sharedSessionData: SessionData?
        @Shared(.lastGoal) var sharedLastGoal: String
        @Shared(.lastTimeMinutes) var sharedLastTimeMinutes: String
        @Shared(.analysisHistory) var sharedAnalysisHistory: [AnalysisResult]
        
        $sharedSessionData.withLock { $0 = sessionData }
        $sharedLastGoal.withLock { $0 = lastGoal }
        $sharedLastTimeMinutes.withLock { $0 = lastTimeMinutes }
        $sharedAnalysisHistory.withLock { $0 = analysisHistory }
        
        // Now create state - the init() will use these shared values
        var state = AppFeature.State()
        
        // Override with specific destination if provided
        if let destination = destination {
            state.destination = destination
        }
        
        // Set regular values
        state.reflectionPath = reflectionPath
        state.isLoading = isLoading
        
        return state
    }
}

// MARK: - Mock Data

extension SessionData {
    static func mock(
        goal: String = "Test Goal",
        startTime: Date = Date(timeIntervalSince1970: 1_700_000_000),
        timeExpected: UInt64 = 30,  // Default to 30 minutes
        reflectionFilePath: String? = nil
    ) -> Self {
        SessionData(
            goal: goal,
            startTime: UInt64(startTime.timeIntervalSince1970),
            timeExpected: timeExpected,
            reflectionFilePath: reflectionFilePath
        )
    }
}

extension AnalysisResult {
    static let mock = AnalysisResult(
        summary: "Test Summary",
        suggestion: "Test Suggestion",
        reasoning: "Test Reasoning"
    )
}

extension ChecklistItem {
    static let mockItems = [
        ChecklistItem(id: "test-1", text: "Close distractions", on: false),
        ChecklistItem(id: "test-2", text: "Set timer", on: false),
        ChecklistItem(id: "test-3", text: "Review goals", on: false)
    ]
}

