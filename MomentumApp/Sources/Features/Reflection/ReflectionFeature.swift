import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct ReflectionFeature {
    private static let logger = Logger(subsystem: "com.bkase.MomentumApp", category: "ReflectionFeature")
    @ObservableState
    struct State: Equatable {
        let reflectionPath: String
        var operationError: String?
    }
    
    enum Action: Equatable {
        case analyzeButtonTapped
        case cancelButtonTapped
        case analyzeResponse(TaskResult<AnalysisResult>)
        case clearOperationError
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case analysisRequested(analysisResult: AnalysisResult)
            case analysisFailedToStart(AppError)
        }
    }
    
    @Dependency(\.rustCoreClient) var rustCoreClient
    @Dependency(\.continuousClock) var clock
    
    enum CancelID { case errorDismissal }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .analyzeButtonTapped:
                state.operationError = nil
                return .run { [reflectionPath = state.reflectionPath] send in
                    await send(
                        .analyzeResponse(
                            await TaskResult {
                                try await rustCoreClient.analyze(reflectionPath)
                            }
                        )
                    )
                }
                
            case .cancelButtonTapped:
                return .none
                
            case let .analyzeResponse(.success(analysisResult)):
                return .send(.delegate(.analysisRequested(analysisResult: analysisResult)))
                
            case let .analyzeResponse(.failure(error)):
                if let rustError = error as? RustCoreError {
                    state.operationError = rustError.errorDescription ?? "An error occurred"
                    Self.logger.error("Failed to analyze reflection - RustCoreError: \(String(describing: rustError))")
                } else {
                    state.operationError = error.localizedDescription
                    Self.logger.error("Failed to analyze reflection: \(error.localizedDescription)")
                }
                // Auto-dismiss operation error after 5 seconds
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.clearOperationError)
                }
                .cancellable(id: CancelID.errorDismissal)
                
            case .clearOperationError:
                state.operationError = nil
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}