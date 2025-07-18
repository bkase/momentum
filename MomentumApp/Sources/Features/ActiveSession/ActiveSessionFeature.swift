import ComposableArchitecture
import Foundation

@Reducer
struct ActiveSessionFeature {
    @ObservableState
    struct State: Equatable {
        let goal: String
        let startTime: Date
        let expectedMinutes: UInt64
        var operationError: String?
    }
    
    enum Action: Equatable {
        case stopButtonTapped
        case performStop
        case stopSessionResponse(TaskResult<String>)
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case sessionStopped(reflectionPath: String)
            case sessionFailedToStop(AppError)
        }
    }
    
    @Dependency(\.rustCoreClient) var rustCoreClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .stopButtonTapped:
                // Just signal that stop was requested - AppFeature will show confirmation
                return .none
                
            case .performStop:
                return .run { send in
                    await send(
                        .stopSessionResponse(
                            await TaskResult {
                                try await rustCoreClient.stop()
                            }
                        )
                    )
                }
                
            case let .stopSessionResponse(.success(reflectionPath)):
                return .send(.delegate(.sessionStopped(reflectionPath: reflectionPath)))
                
            case let .stopSessionResponse(.failure(error)):
                state.operationError = error.localizedDescription
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}