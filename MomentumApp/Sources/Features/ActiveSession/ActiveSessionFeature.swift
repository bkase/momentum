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
        var hasApproachEventFired = false
        var hasTimeoutEventFired = false
    }

    enum Action: Equatable {
        case stopButtonTapped
        case performStop
        case stopSessionResponse(TaskResult<String>)
        case clearOperationError
        case startTimers
        case approachTimerFired
        case timeoutTimerFired
        case cancelTimers
        case delegate(Delegate)

        enum Delegate: Equatable {
            case sessionStopped(reflectionPath: String)
            case sessionFailedToStop(AppError)
            case approachFired
            case timeoutFired
        }
    }

    @Dependency(\.a4Client) var a4Client
    @Dependency(\.continuousClock) var clock

    enum CancelID { case errorDismissal, approachTimer, timeoutTimer }

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
                                try await a4Client.stop()
                            }
                        )
                    )
                }

            case let .stopSessionResponse(.success(reflectionPath)):
                state.hasApproachEventFired = false
                state.hasTimeoutEventFired = false
                return .merge(
                    .cancel(id: CancelID.approachTimer),
                    .cancel(id: CancelID.timeoutTimer),
                    .send(.delegate(.sessionStopped(reflectionPath: reflectionPath)))
                )

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

            case .startTimers:
                let totalSeconds = TimeInterval(state.expectedMinutes) * 60
                let approachLeadSeconds: TimeInterval = totalSeconds <= 7 * 60 ? 2 * 60 : 5 * 60
                let sessionEnd = state.startTime.addingTimeInterval(totalSeconds)
                let now = Date()
                let remainingSeconds = sessionEnd.timeIntervalSince(now)

                // If the session appears to already be over, immediately emit timeout
                if remainingSeconds <= 0 {
                    state.hasTimeoutEventFired = true
                    state.hasApproachEventFired = true
                    return .send(.delegate(.timeoutFired))
                }

                var effects: [Effect<Action>] = []

                if !state.hasApproachEventFired {
                    let approachDelay = remainingSeconds - approachLeadSeconds
                    if approachDelay <= 0 {
                        state.hasApproachEventFired = true
                        effects.append(.send(.delegate(.approachFired)))
                    } else {
                        effects.append(
                            .run { send in
                                try await clock.sleep(for: .seconds(approachDelay))
                                await send(.approachTimerFired)
                            }
                            .cancellable(id: CancelID.approachTimer, cancelInFlight: true)
                        )
                    }
                }

                if !state.hasTimeoutEventFired {
                    effects.append(
                        .run { send in
                            try await clock.sleep(for: .seconds(remainingSeconds))
                            await send(.timeoutTimerFired)
                        }
                        .cancellable(id: CancelID.timeoutTimer, cancelInFlight: true)
                    )
                }

                return .merge(effects)

            case .approachTimerFired:
                if state.hasApproachEventFired {
                    return .none
                }
                state.hasApproachEventFired = true
                return .send(.delegate(.approachFired))

            case .timeoutTimerFired:
                if state.hasTimeoutEventFired {
                    return .none
                }
                state.hasTimeoutEventFired = true
                return .merge(
                    .cancel(id: CancelID.approachTimer),
                    .send(.delegate(.timeoutFired))
                )

            case .cancelTimers:
                return .merge(
                    .cancel(id: CancelID.approachTimer),
                    .cancel(id: CancelID.timeoutTimer)
                )

            case .delegate:
                return .none
            }
        }
    }
}
