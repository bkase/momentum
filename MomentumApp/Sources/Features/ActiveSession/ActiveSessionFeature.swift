import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct ActiveSessionFeature {
    private static let logger = Logger(subsystem: "com.bkase.MomentumApp", category: "ActiveSessionFeature")
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
        case clearOperationError
        case delegate(Delegate)

        enum Delegate: Equatable {
            case sessionStopped(reflectionPath: String)
            case sessionFailedToStop(AppError)
        }
    }

    @Dependency(\.rustCoreClient) var rustCoreClient
    @Dependency(\.continuousClock) var clock

    enum CancelID { case errorDismissal }

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
                            TaskResult {
                                try await rustCoreClient.stop()
                            }
                        )
                    )
                }

            case let .stopSessionResponse(.success(reflectionPath)):
                return .send(.delegate(.sessionStopped(reflectionPath: reflectionPath)))

            case let .stopSessionResponse(.failure(error)):
                state.operationError = error.localizedDescription
                Self.logger.error("Failed to stop session: \(error.localizedDescription)")
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
