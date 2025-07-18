import ComposableArchitecture
import Foundation

extension AppFeature {
    // MARK: - Effect Helpers
    
    
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
        case let .analysisComplete(analysis):
            state.reflectionPath = nil
            state.$analysisHistory.withLock { $0.append(analysis) }
            state.destination = .analysis(AnalysisFeature.State(analysis: analysis))
        }
    }
}