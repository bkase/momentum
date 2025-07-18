import ComposableArchitecture
import Foundation

@Reducer
struct ReflectionFeature {
    @ObservableState
    struct State: Equatable {
        let reflectionPath: String
        var operationError: String?
    }
    
    enum Action: Equatable {
        case analyzeButtonTapped
        case cancelButtonTapped
        case analyzeResponse(TaskResult<AnalysisResult>)
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case analysisRequested(analysisResult: AnalysisResult)
            case analysisFailedToStart(AppError)
        }
    }
    
    @Dependency(\.rustCoreClient) var rustCoreClient
    
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
                } else {
                    state.operationError = error.localizedDescription
                }
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}