import ComposableArchitecture
import Foundation
import Observation
import Sharing

extension AppFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.sessionData) var sessionData: SessionData? = nil
        @Shared(.lastGoal) var lastGoal = ""
        @Shared(.lastTimeMinutes) var lastTimeMinutes = "30"
        @Shared(.analysisHistory) var analysisHistory: [AnalysisResult] = []
        
        @Presents var destination: Destination.State?
        
        var isLoading = false
        var reflectionPath: String?
        
        init() {
            // Initialize destination based on shared state
            if let analysis = analysisHistory.last {
                self.destination = .analysis(AnalysisFeature.State(analysis: analysis))
            } else if let sessionData = sessionData {
                self.destination = .activeSession(ActiveSessionFeature.State(
                    goal: sessionData.goal,
                    startTime: sessionData.startDate,
                    expectedMinutes: sessionData.expectedMinutes
                ))
            } else {
                self.destination = .preparation(PreparationFeature.State(
                    goal: lastGoal,
                    timeInput: lastTimeMinutes
                ))
            }
        }
    }
    
    @CasePathable
    enum Action: Equatable {
        case destination(PresentationAction<Destination.Action>)
        case onAppear
        case resetToIdle
        case cancelCurrentOperation
    }
    
}