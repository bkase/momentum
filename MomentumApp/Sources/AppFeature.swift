import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @Dependency(\.a4Client) var a4Client
    #if DEBUG
        @Dependency(\.testServer) var testServer
    #endif

    enum CancelID { case rustOperation }

    @Reducer(state: .equatable, action: .equatable)
    enum Destination {
        case preparation(PreparationFeature)
        case activeSession(ActiveSessionFeature)
        case reflection(ReflectionFeature)
        case analysis(AnalysisFeature)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Load session data from aethel first
                return .run { send in
                    do {
                        let sessionData = try await a4Client.getSession()
                        await send(.sessionDataLoaded(sessionData))
                    } catch {
                        // Log error but continue - no session is valid state
                        print("Failed to load session from aethel: \(error)")
                        await send(.sessionDataLoaded(nil))
                    }
                }

            case let .sessionDataLoaded(sessionData):
                // Update shared session data
                state.$sessionData.withLock { $0 = sessionData }

                // Set initial destination based on current state
                var effects: [Effect<Action>] = []
                if let analysis = state.analysisHistory.last {
                    state.destination = .analysis(AnalysisFeature.State(analysis: analysis))
                } else if let reflectionPath = state.reflectionPath {
                    state.destination = .reflection(ReflectionFeature.State(reflectionPath: reflectionPath))
                } else if let sessionData = sessionData {
                    state.destination = .activeSession(
                        ActiveSessionFeature.State(
                            goal: sessionData.goal,
                            startTime: sessionData.startDate,
                            expectedMinutes: sessionData.expectedMinutes
                        ))
                } else {
                    state.destination = .preparation(
                        PreparationFeature.State(
                            goal: state.lastGoal,
                            timeInput: state.lastTimeMinutes
                        ))
                }
                if sessionData != nil {
                    state.menuBarPhase = .normal
                    effects.append(.run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .menuBarSetNormalIcon, object: nil)
                        }
                    })
                    effects.append(.send(.destination(.presented(.activeSession(.startTimers)))))
                } else if state.menuBarPhase != .normal {
                    state.menuBarPhase = .normal
                    effects.append(.run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .menuBarSetNormalIcon, object: nil)
                        }
                    })
                }
                return .merge(effects)

            case let .destination(.presented(.preparation(.goalChanged(goal)))):
                // Save goal to shared state
                state.$lastGoal.withLock { $0 = goal }
                return .none

            case let .destination(.presented(.preparation(.timeInputChanged(time)))):
                // Save time to shared state
                state.$lastTimeMinutes.withLock { $0 = time }
                return .none

            case .destination(.presented(.preparation(.startButtonTapped))):
                // PreparationFeature now handles this internally
                return .none

            case let .destination(.presented(.preparation(.delegate(.sessionStarted(sessionData))))):
                // Handle successful session start from PreparationFeature
                state.isLoading = false
                state.$sessionData.withLock { $0 = sessionData }
                state.reflectionPath = nil
                state.$analysisHistory.withLock { $0 = [] }
                state.destination = .activeSession(
                    ActiveSessionFeature.State(
                        goal: sessionData.goal,
                        startTime: sessionData.startDate,
                        expectedMinutes: sessionData.expectedMinutes
                    ))
                state.menuBarPhase = .normal
                return .merge(
                    .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .menuBarSetNormalIcon, object: nil)
                        }
                    },
                    .send(.destination(.presented(.activeSession(.startTimers))))
                )

            case let .destination(.presented(.preparation(.delegate(.sessionFailedToStart(error))))):
                // Handle failed session start from PreparationFeature
                state.isLoading = false
                // Error handled in PreparationView
                return .none

            case .destination(.presented(.activeSession(.stopButtonTapped))):
                // Stop session immediately
                state.isLoading = true
                return .send(.destination(.presented(.activeSession(.performStop))))

            case let .destination(.presented(.activeSession(.delegate(.sessionStopped(reflectionPath))))):
                // Handle successful session stop from ActiveSessionFeature
                state.isLoading = false
                state.$sessionData.withLock { $0 = nil }
                state.reflectionPath = reflectionPath
                state.destination = .reflection(ReflectionFeature.State(reflectionPath: reflectionPath))
                if state.menuBarPhase != .normal {
                    state.menuBarPhase = .normal
                    return .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .menuBarSetNormalIcon, object: nil)
                        }
                    }
                }
                return .none

            case let .destination(.presented(.activeSession(.delegate(.sessionFailedToStop(error))))):
                // Handle failed session stop from ActiveSessionFeature
                state.isLoading = false
                // Error handled in ActiveSessionView
                return .none

            case .destination(.presented(.activeSession(.delegate(.approachFired)))):
                if state.menuBarPhase == .timeout {
                    return .none
                }
                state.menuBarPhase = .approach
                return .merge(
                    .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .menuBarSetApproachIcon, object: nil)
                        }
                    },
                    .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .showApproachMicroPopover, object: nil)
                        }
                    }
                )

            case .destination(.presented(.activeSession(.delegate(.timeoutFired)))):
                state.menuBarPhase = .timeout
                return .merge(
                    .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .menuBarSetTimeoutIcon, object: nil)
                        }
                    },
                    .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: .showTimeoutMicroPopover, object: nil)
                        }
                    }
                )

            case .destination(.presented(.reflection(.analyzeButtonTapped))):
                // ReflectionFeature will handle the analysis
                state.isLoading = true
                return .none

            case let .destination(.presented(.reflection(.delegate(.analysisRequested(analysisResult))))):
                // Handle successful analysis from ReflectionFeature
                state.isLoading = false
                state.reflectionPath = nil
                state.$analysisHistory.withLock { $0.append(analysisResult) }
                state.destination = .analysis(AnalysisFeature.State(analysis: analysisResult))
                return .none

            case let .destination(.presented(.reflection(.delegate(.analysisFailedToStart(error))))):
                // Handle failed analysis from ReflectionFeature
                state.isLoading = false
                // Error handled in AwaitingAnalysisView
                return .none

            case .destination(.presented(.reflection(.cancelButtonTapped))):
                state.destination = nil
                state.reflectionPath = nil
                // Go back to preparation
                state.destination = .preparation(
                    PreparationFeature.State(
                        goal: state.lastGoal,
                        timeInput: state.lastTimeMinutes
                    ))
                return .none

            case .destination(.presented(.analysis(.resetButtonTapped))):
                // Reset immediately
                return .send(.resetToIdle)

            case .destination(.presented(.analysis(.dismissButtonTapped))):
                state.destination = nil
                // Keep analysis in history but go to preparation
                state.destination = .preparation(
                    PreparationFeature.State(
                        goal: state.lastGoal,
                        timeInput: state.lastTimeMinutes
                    ))
                return .none

            case .resetToIdle:
                state.$sessionData.withLock { $0 = nil }
                state.reflectionPath = nil
                state.$analysisHistory.withLock { $0 = [] }
                state.isLoading = false
                state.destination = .preparation(
                    PreparationFeature.State(
                        goal: state.lastGoal,
                        timeInput: state.lastTimeMinutes
                    ))
                if state.menuBarPhase != .normal {
                    state.menuBarPhase = .normal
                    return .merge(
                        .cancel(id: CancelID.rustOperation),
                        .run { _ in
                            await MainActor.run {
                                NotificationCenter.default.post(name: .menuBarSetNormalIcon, object: nil)
                            }
                        }
                    )
                }
                return .cancel(id: CancelID.rustOperation)

            case .cancelCurrentOperation:
                state.isLoading = false
                return .cancel(id: CancelID.rustOperation)

            #if DEBUG
                case .testServerShowMenu:
                    // Force the menu to be visible - this would be handled by the view
                    TestLogger.log("Test server requested menu show")
                    return .none

                case .testServerRefreshState:
                    // Force reload state from disk
                    TestLogger.log("Test server requested state refresh")
                    return .send(.onAppear)

                case .startTestServer:
                    return .run { _ in
                        try await testServer.start(8765)
                        TestLogger.log("Test server started on port 8765")
                    }
            #endif

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
