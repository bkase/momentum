import ComposableArchitecture
import Foundation
import Sharing
import Testing

@testable import MomentumApp

@Suite("PreparationFeature Tests")
@MainActor
struct PreparationFeatureTests {
    init() {
        // Reset shared state before each test
        @Shared(.sessionData) var sessionData: SessionData?
        @Shared(.lastGoal) var lastGoal: String
        @Shared(.lastTimeMinutes) var lastTimeMinutes: String

        $sessionData.withLock { $0 = nil }
        $lastGoal.withLock { $0 = "" }
        $lastTimeMinutes.withLock { $0 = "30" }
    }

    @Test("Start session with valid inputs sends success delegate")
    func startSessionSuccess() async {
        let testSessionData = SessionData(
            goal: "Test goal",
            startTime: 1_700_000_000,
            timeExpected: 30,
            reflectionFilePath: nil
        )

        var initialState = PreparationFeature.State(
            goal: "Test goal",
            timeInput: "30"
        )
        // Set checklist items directly on state
        initialState.checklistItems = (0..<10).map { i in
            ChecklistItem(id: String(i), text: "Item \(i)", on: true)
        }

        let store = TestStore(
            initialState: initialState
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.a4Client.start = { goal, minutes in
                #expect(goal == "Test goal")
                #expect(minutes == 30)
                return testSessionData
            }
        }

        await store.send(.startButtonTapped)
        await store.receive(.startSessionResponse(.success(testSessionData)))
        await store.receive(.delegate(.sessionStarted(testSessionData)))
    }

    @Test("Start session with empty goal shows error")
    func startSessionEmptyGoal() async {
        let store = TestStore(
            initialState: PreparationFeature.State(
                goal: "",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        }

        await store.send(.startButtonTapped) {
            $0.operationError = "Please enter a goal"
        }
    }

    @Test("Start session with invalid time shows error")
    func startSessionInvalidTime() async {
        let store = TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "invalid"
            )
        ) {
            PreparationFeature()
        }

        await store.send(.startButtonTapped) {
            $0.operationError = "Please enter a valid time in minutes"
        }
    }

    @Test("Start session with zero time shows error")
    func startSessionZeroTime() async {
        let store = TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "0"
            )
        ) {
            PreparationFeature()
        }

        await store.send(.startButtonTapped) {
            $0.operationError = "Please enter a valid time in minutes"
        }
    }

    @Test("Start session with RustCoreError shows error")
    func startSessionRustCoreError() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.a4Client.start = { _, _ in
                throw RustCoreError.binaryNotFound
            }
            $0.continuousClock = clock
        }

        await store.send(.startButtonTapped)
        await store.receive(.startSessionResponse(.failure(RustCoreError.binaryNotFound))) {
            $0.operationError = "Momentum CLI has been removed; operations now rely on Swift A4Core functionality"
        }

        // Advance clock to trigger error dismissal
        await clock.advance(by: .seconds(5))
        await store.receive(.clearOperationError) {
            $0.operationError = nil
        }
    }

    @Test("Start session with generic error shows error")
    func startSessionGenericError() async {
        struct TestError: Error, LocalizedError, Equatable {
            var errorDescription: String? { "Test error" }
        }

        let clock = TestClock()
        let store = TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.a4Client.start = { _, _ in
                throw TestError()
            }
            $0.continuousClock = clock
        }

        await store.send(.startButtonTapped)
        await store.receive(.startSessionResponse(.failure(TestError()))) {
            $0.operationError = "Test error"
        }

        // Advance clock to trigger error dismissal
        await clock.advance(by: .seconds(5))
        await store.receive(.clearOperationError) {
            $0.operationError = nil
        }
    }

    @Test("Goal and time changes update state and clear errors")
    func goalAndTimeChanges() async {
        var initialState = PreparationFeature.State()
        initialState.operationError = "Some error"

        let store = TestStore(
            initialState: initialState
        ) {
            PreparationFeature()
        }

        await store.send(.goalChanged("New goal")) {
            $0.goal = "New goal"
            $0.operationError = nil  // Error should be cleared
        }

        // Set error again
        await store.send(.startButtonTapped) {
            $0.operationError = "Please enter a valid time in minutes"
        }

        await store.send(.timeInputChanged("45")) {
            $0.timeInput = "45"
            $0.operationError = nil  // Error should be cleared
        }
    }
}
