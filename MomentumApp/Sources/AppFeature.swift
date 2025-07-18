import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @Dependency(\.rustCoreClient) var rustCoreClient

    enum CancelID { case rustOperation }
    
    @Reducer(state: .equatable, action: .equatable)
    enum Destination {
        case preparation(PreparationFeature)
        case activeSession(ActiveSessionFeature)
        case reflection(ReflectionFeature)
        case analysis(AnalysisFeature)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Set initial destination based on current state
                if let analysis = state.analysisHistory.last {
                    state.destination = .analysis(AnalysisFeature.State(analysis: analysis))
                } else if let reflectionPath = state.reflectionPath {
                    state.destination = .reflection(ReflectionFeature.State(reflectionPath: reflectionPath))
                } else if let sessionData = state.sessionData {
                    state.destination = .activeSession(ActiveSessionFeature.State(
                        goal: sessionData.goal,
                        startTime: sessionData.startDate,
                        expectedMinutes: sessionData.expectedMinutes
                    ))
                } else {
                    state.destination = .preparation(PreparationFeature.State(
                        goal: state.lastGoal,
                        timeInput: state.lastTimeMinutes
                    ))
                }
                return .none
                
            case .destination(.presented(.preparation(.goalChanged(let goal)))):
                // Save goal to shared state
                state.$lastGoal.withLock { $0 = goal }
                return .none
                
            case .destination(.presented(.preparation(.timeInputChanged(let time)))):
                // Save time to shared state
                state.$lastTimeMinutes.withLock { $0 = time }
                return .none
                
            case .destination(.presented(.preparation(.startButtonTapped))):
                // PreparationFeature now handles this internally
                return .none
                
            case let .destination(.presented(.preparation(.delegate(.sessionStarted(sessionData))))):
                // Handle successful session start from PreparationFeature
                state.isLoading = false
                state.$sessionData.withLock { $0 = sessionData }
                state.reflectionPath = nil
                state.$analysisHistory.withLock { $0 = [] }
                state.destination = .activeSession(ActiveSessionFeature.State(
                    goal: sessionData.goal,
                    startTime: sessionData.startDate,
                    expectedMinutes: sessionData.expectedMinutes
                ))
                return .none
                
            case let .destination(.presented(.preparation(.delegate(.sessionFailedToStart(error))))):
                // Handle failed session start from PreparationFeature
                state.isLoading = false
                // Error handled in PreparationView
                return .none
                
            case .destination(.presented(.activeSession(.stopButtonTapped))):
                // Stop session immediately
                state.isLoading = true
                return .send(.destination(.presented(.activeSession(.performStop))))
                
            case let .destination(.presented(.activeSession(.delegate(.sessionStopped(reflectionPath))))):
                // Handle successful session stop from ActiveSessionFeature
                state.isLoading = false
                state.$sessionData.withLock { $0 = nil }
                state.reflectionPath = reflectionPath
                state.destination = .reflection(ReflectionFeature.State(reflectionPath: reflectionPath))
                return .none
                
            case let .destination(.presented(.activeSession(.delegate(.sessionFailedToStop(error))))):
                // Handle failed session stop from ActiveSessionFeature
                state.isLoading = false
                // Error handled in ActiveSessionView
                return .none
                
            case .destination(.presented(.reflection(.analyzeButtonTapped))):
                // ReflectionFeature will handle the analysis
                state.isLoading = true
                return .none
                
            case let .destination(.presented(.reflection(.delegate(.analysisRequested(analysisResult))))):
                // Handle successful analysis from ReflectionFeature
                state.isLoading = false
                state.reflectionPath = nil
                state.$analysisHistory.withLock { $0.append(analysisResult) }
                state.destination = .analysis(AnalysisFeature.State(analysis: analysisResult))
                return .none
                
            case let .destination(.presented(.reflection(.delegate(.analysisFailedToStart(error))))):
                // Handle failed analysis from ReflectionFeature
                state.isLoading = false
                // Error handled in AwaitingAnalysisView
                return .none
                
            case .destination(.presented(.reflection(.cancelButtonTapped))):
                state.destination = nil
                state.reflectionPath = nil
                // Go back to preparation
                state.destination = .preparation(PreparationFeature.State(
                    goal: state.lastGoal,
                    timeInput: state.lastTimeMinutes
                ))
                return .none
                
            case .destination(.presented(.analysis(.resetButtonTapped))):
                // Reset immediately
                return .send(.resetToIdle)
                
            case .destination(.presented(.analysis(.dismissButtonTapped))):
                state.destination = nil
                // Keep analysis in history but go to preparation
                state.destination = .preparation(PreparationFeature.State(
                    goal: state.lastGoal,
                    timeInput: state.lastTimeMinutes
                ))
                return .none
                




            case .resetToIdle:
                state.$sessionData.withLock { $0 = nil }
                state.reflectionPath = nil
                state.$analysisHistory.withLock { $0 = [] }
                state.isLoading = false
                state.destination = .preparation(PreparationFeature.State(
                    goal: state.lastGoal,
                    timeInput: state.lastTimeMinutes
                ))
                return .cancel(id: CancelID.rustOperation)

            case .cancelCurrentOperation:
                state.isLoading = false
                return .cancel(id: CancelID.rustOperation)
                
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}