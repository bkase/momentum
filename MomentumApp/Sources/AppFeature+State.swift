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
        @Presents var alert: AlertState<Alert>?
        @Presents var confirmationDialog: ConfirmationDialogState<ConfirmationDialog>?
        
        var isLoading = false
        var reflectionPath: String?
        
        enum Alert: Equatable {
            case dismiss
            case retry
            case openSettings
            case contactSupport
        }
        
        enum ConfirmationDialog: Equatable {
            case confirmStopSession
            case confirmReset
            case cancel
        }
        
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
        case alert(PresentationAction<State.Alert>)
        case confirmationDialog(PresentationAction<State.ConfirmationDialog>)
        case onAppear
        case rustCoreResponse(TaskResult<RustCoreResponse>)
        case startSession(goal: String, minutes: UInt64)
        case stopSession
        case analyzeReflection(path: String)
        case resetToIdle
        case cancelCurrentOperation
    }
    
    enum RustCoreResponse: Equatable {
        case sessionStarted(SessionData)
        case sessionStopped(reflectionPath: String)
        case analysisComplete(AnalysisResult)
    }
}