import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @Dependency(\.rustCoreClient) var rustCoreClient

    enum CancelID { case rustOperation }

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
                return Self.handleStartFromPreparation(state: &state)
                
            case .destination(.presented(.activeSession(.stopButtonTapped))):
                state.confirmationDialog = .stopSession()
                return .none
                
            case .destination(.presented(.reflection(.analyzeButtonTapped))):
                if let path = state.reflectionPath {
                    return .send(.analyzeReflection(path: path))
                }
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
                state.confirmationDialog = .resetToIdle()
                return .none
                
            case .destination(.presented(.analysis(.dismissButtonTapped))):
                state.destination = nil
                // Keep analysis in history but go to preparation
                state.destination = .preparation(PreparationFeature.State(
                    goal: state.lastGoal,
                    timeInput: state.lastTimeMinutes
                ))
                return .none
                
            case let .startSession(goal, minutes):
                return Self.startSessionEffect(
                    state: &state,
                    goal: goal,
                    minutes: minutes,
                    rustCoreClient: rustCoreClient
                )

            case .stopSession:
                return Self.stopSessionEffect(
                    state: &state,
                    rustCoreClient: rustCoreClient
                )

            case let .analyzeReflection(path):
                return Self.analyzeReflectionEffect(
                    state: &state,
                    path: path,
                    rustCoreClient: rustCoreClient
                )

            case let .rustCoreResponse(.success(response)):
                Self.handleRustCoreSuccess(state: &state, response: response)
                return .none

            case let .rustCoreResponse(.failure(error)):
                state.isLoading = false
                state.alert = .error(error)
                return .none

            case .resetToIdle:
                state.$sessionData.withLock { $0 = nil }
                state.reflectionPath = nil
                state.$analysisHistory.withLock { $0 = [] }
                state.alert = nil
                state.isLoading = false
                state.destination = .preparation(PreparationFeature.State(
                    goal: state.lastGoal,
                    timeInput: state.lastTimeMinutes
                ))
                return .cancel(id: CancelID.rustOperation)

            case .cancelCurrentOperation:
                state.isLoading = false
                return .cancel(id: CancelID.rustOperation)
                
            case .alert(.presented(.dismiss)):
                // Alert dismissed, no action needed
                return .none
                
            case .alert(.presented(.retry)):
                // Retry the last failed operation
                // For now, we'll just dismiss the alert
                state.alert = nil
                return .none
                
            case .alert(.presented(.openSettings)):
                // TODO: Open settings when implemented
                state.alert = nil
                return .none
                
            case .alert(.presented(.contactSupport)):
                // TODO: Open support link when implemented
                state.alert = nil
                return .none
                
            case .alert(.dismiss):
                return .none
                
            case .confirmationDialog(.presented(.confirmStopSession)):
                state.confirmationDialog = nil
                return .send(.stopSession)
                
            case .confirmationDialog(.presented(.confirmReset)):
                state.confirmationDialog = nil
                return .send(.resetToIdle)
                
            case .confirmationDialog(.presented(.cancel)):
                state.confirmationDialog = nil
                return .none
                
            case .confirmationDialog(.dismiss):
                return .none
                
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}