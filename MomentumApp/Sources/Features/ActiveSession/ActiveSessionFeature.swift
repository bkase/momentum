import ComposableArchitecture
import Foundation

@Reducer
struct ActiveSessionFeature {
    @ObservableState
    struct State: Equatable {
        let goal: String
        let startTime: Date
        let expectedMinutes: UInt64
    }
    
    enum Action: Equatable {
        case stopButtonTapped
        case performStop
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
                    do {
                        let reflectionPath = try await rustCoreClient.stop()
                        await send(.delegate(.sessionStopped(reflectionPath: reflectionPath)))
                    } catch {
                        await send(.delegate(.sessionFailedToStop(.other(error.localizedDescription))))
                    }
                }
                
            case .delegate:
                return .none
            }
        }
    }
}