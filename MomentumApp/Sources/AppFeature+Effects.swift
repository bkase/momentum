import ComposableArchitecture
import Foundation

extension AppFeature {
    // MARK: - Effect Helpers
    
    static func handleStartFromPreparation(state: inout State) -> Effect<Action> {
        guard case let .preparation(preparationState) = state.destination else {
            return .none
        }
        
        guard let minutes = UInt64(preparationState.timeInput) else {
            state.alert = .invalidTime()
            return .none
        }
        
        return .send(.startSession(goal: preparationState.goal, minutes: minutes))
    }
    
    static func startSessionEffect(
        state: inout State,
        goal: String,
        minutes: UInt64,
        rustCoreClient: RustCoreClient
    ) -> Effect<Action> {
        guard state.sessionData == nil else {
            state.alert = .sessionAlreadyActive()
            return .none
        }

        state.isLoading = true
        state.alert = nil

        return .run { send in
            await send(
                .rustCoreResponse(
                    await TaskResult {
                        try await .sessionStarted(
                            rustCoreClient.start(goal, Int(minutes))
                        )
                    }
                )
            )
        }
        .cancellable(id: CancelID.rustOperation)
    }
    
    static func stopSessionEffect(
        state: inout State,
        rustCoreClient: RustCoreClient
    ) -> Effect<Action> {
        guard state.sessionData != nil else {
            state.alert = .noActiveSession()
            return .none
        }

        state.isLoading = true
        state.alert = nil

        return .run { send in
            await send(
                .rustCoreResponse(
                    await TaskResult {
                        try await .sessionStopped(reflectionPath: rustCoreClient.stop())
                    }
                )
            )
        }
        .cancellable(id: CancelID.rustOperation)
    }
    
    static func analyzeReflectionEffect(
        state: inout State,
        path: String,
        rustCoreClient: RustCoreClient
    ) -> Effect<Action> {
        state.isLoading = true
        state.alert = nil

        return .run { send in
            await send(
                .rustCoreResponse(
                    await TaskResult {
                        try await .analysisComplete(rustCoreClient.analyze(path))
                    }
                )
            )
        }
        .cancellable(id: CancelID.rustOperation)
    }
    
    static func handleRustCoreSuccess(
        state: inout State,
        response: RustCoreResponse
    ) {
        state.isLoading = false

        switch response {
        case let .sessionStarted(sessionData):
            state.$sessionData.withLock { $0 = sessionData }
            state.reflectionPath = nil
            state.$analysisHistory.withLock { $0 = [] }
            state.destination = .activeSession(ActiveSessionFeature.State(
                goal: sessionData.goal,
                startTime: sessionData.startDate,
                expectedMinutes: sessionData.expectedMinutes
            ))

        case let .sessionStopped(reflectionPath):
            state.$sessionData.withLock { $0 = nil }
            state.reflectionPath = reflectionPath
            state.destination = .reflection(ReflectionFeature.State(reflectionPath: reflectionPath))

        case let .analysisComplete(analysis):
            state.reflectionPath = nil
            state.$analysisHistory.withLock { $0.append(analysis) }
            state.destination = .analysis(AnalysisFeature.State(analysis: analysis))
        }
    }
}