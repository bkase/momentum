import ComposableArchitecture
import Foundation

@Reducer
struct ReflectionFeature {
    @ObservableState
    struct State: Equatable {
        let reflectionPath: String
    }
    
    enum Action: Equatable {
        case analyzeButtonTapped
        case cancelButtonTapped
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
                return .run { [reflectionPath = state.reflectionPath] send in
                    do {
                        let analysisResult = try await rustCoreClient.analyze(reflectionPath)
                        await send(.delegate(.analysisRequested(analysisResult: analysisResult)))
                    } catch {
                        await send(.delegate(.analysisFailedToStart(.other(error.localizedDescription))))
                    }
                }
                
            case .cancelButtonTapped:
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}