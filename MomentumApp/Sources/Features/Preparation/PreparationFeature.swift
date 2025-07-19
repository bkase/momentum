import ComposableArchitecture
import Foundation
import Sharing
import OSLog

@Reducer
struct PreparationFeature {
    private static let logger = Logger(subsystem: "com.bkase.MomentumApp", category: "PreparationFeature")
    @ObservableState
    struct State: Equatable {
        var goal: String = ""
        var timeInput: String = ""
        var checklistItems: [ChecklistItem] = []
        var isLoadingChecklist: Bool = false
        var operationError: String?
        
        var goalValidationError: String? {
            let invalidCharacters = CharacterSet(charactersIn: "/:*?\"<>|")
            if goal.rangeOfCharacter(from: invalidCharacters) != nil {
                return "Goal contains invalid characters. Please avoid: / : * ? \" < > |"
            }
            return nil
        }
        
        var isStartButtonEnabled: Bool {
            !goal.isEmpty &&
            Int(timeInput).map { $0 > 0 } == true &&
            checklistItems.allSatisfy { $0.on } &&
            goalValidationError == nil
        }
        
        init(
            goal: String = "",
            timeInput: String = ""
        ) {
            self.goal = goal
            self.timeInput = timeInput
        }
        
        init(preparationState: PreparationState) {
            self.goal = preparationState.goal
            self.timeInput = preparationState.timeInput
            // Checklist will be loaded from Rust CLI
        }
        
        var preparationState: PreparationState {
            PreparationState(
                goal: goal,
                timeInput: timeInput,
                checklist: IdentifiedArray(uniqueElements: []) // No longer used
            )
        }
    }
    
    enum Action: Equatable {
        case onAppear
        case loadChecklist
        case checklistResponse(TaskResult<ChecklistState>)
        case checklistItemToggled(id: String)
        case checklistToggleResponse(TaskResult<ChecklistState>)
        case goalChanged(String)
        case timeInputChanged(String)
        case startButtonTapped
        case startSessionResponse(TaskResult<SessionData>)
        case clearOperationError
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case sessionStarted(SessionData)
            case sessionFailedToStart(AppError)
        }
    }
    
    @Dependency(\.continuousClock) var clock
    @Dependency(\.rustCoreClient) var rustCoreClient
    
    enum CancelID { case errorDismissal }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case .onAppear:
                return .send(.loadChecklist)
                
            case .loadChecklist:
                state.isLoadingChecklist = true
                return .run { send in
                    await send(
                        .checklistResponse(
                            await TaskResult {
                                try await rustCoreClient.checkList()
                            }
                        )
                    )
                }
                
            case let .checklistResponse(.success(checklistState)):
                state.isLoadingChecklist = false
                state.checklistItems = checklistState.items
                return .none
                
            case let .checklistResponse(.failure(error)):
                state.isLoadingChecklist = false
                state.operationError = "Failed to load checklist: \(error.localizedDescription)"
                Self.logger.error("Failed to load checklist: \(error)")
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.clearOperationError)
                }
                .cancellable(id: CancelID.errorDismissal)
                
            case let .checklistItemToggled(id):
                return .run { send in
                    await send(
                        .checklistToggleResponse(
                            await TaskResult {
                                try await rustCoreClient.checkToggle(id)
                            }
                        )
                    )
                }
                
            case let .checklistToggleResponse(.success(checklistState)):
                state.checklistItems = checklistState.items
                return .none
                
            case let .checklistToggleResponse(.failure(error)):
                state.operationError = "Failed to toggle checklist item: \(error.localizedDescription)"
                Self.logger.error("Failed to toggle checklist item: \(error)")
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.clearOperationError)
                }
                .cancellable(id: CancelID.errorDismissal)
                
            case let .goalChanged(newGoal):
                state.goal = newGoal
                // Clear operation error when user types
                state.operationError = nil
                return .none
                
            case let .timeInputChanged(newTime):
                state.timeInput = newTime
                // Clear operation error when user types
                state.operationError = nil
                return .none
                
            case .startButtonTapped:
                // Clear any previous errors
                state.operationError = nil
                
                // Validate inputs
                guard let minutes = UInt64(state.timeInput), minutes > 0 else {
                    let error = "Please enter a valid time in minutes"
                    state.operationError = error
                    Self.logger.error("Start button validation failed: \(error)")
                    return .none
                }
                
                guard !state.goal.isEmpty else {
                    let error = "Please enter a goal"
                    state.operationError = error
                    Self.logger.error("Start button validation failed: \(error)")
                    return .none
                }
                
                // Start the session
                return .run { [goal = state.goal] send in
                    await send(
                        .startSessionResponse(
                            await TaskResult {
                                try await rustCoreClient.start(goal, Int(minutes))
                            }
                        )
                    )
                }
                
            case let .startSessionResponse(.success(sessionData)):
                return .send(.delegate(.sessionStarted(sessionData)))
                
            case let .startSessionResponse(.failure(error)):
                if let rustError = error as? RustCoreError {
                    state.operationError = rustError.errorDescription ?? "An error occurred"
                    Self.logger.error("Failed to start session - RustCoreError: \(String(describing: rustError))")
                } else {
                    state.operationError = error.localizedDescription
                    Self.logger.error("Failed to start session: \(error.localizedDescription)")
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
                // Delegate actions are handled by parent
                return .none
            }
        }
    }
}