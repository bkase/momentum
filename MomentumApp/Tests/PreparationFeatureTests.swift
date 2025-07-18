import ComposableArchitecture
import Foundation
import Testing

@testable import MomentumApp

@Suite("PreparationFeature Tests")
struct PreparationFeatureTests {
    @Test("Start session with valid inputs sends success delegate")
    func startSessionSuccess() async {
        let testSessionData = SessionData(
            goal: "Test goal",
            startTime: 1_700_000_000,
            timeExpected: 30,
            reflectionFilePath: nil
        )
        
        let store = await TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.rustCoreClient.start = { goal, minutes in
                #expect(goal == "Test goal")
                #expect(minutes == 30)
                return testSessionData
            }
        }
        
        await store.send(.startButtonTapped)
        await store.receive(.startSessionResponse(.success(testSessionData)))
        await store.receive(.delegate(.sessionStarted(testSessionData)))
    }
    
    @Test("Start session with empty goal sends error delegate")
    func startSessionEmptyGoal() async {
        let store = await TestStore(
            initialState: PreparationFeature.State(
                goal: "",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        }
        
        await store.send(.startButtonTapped)
        await store.receive(.delegate(.sessionFailedToStart(.invalidInput(reason: "Please enter a goal"))))
    }
    
    @Test("Start session with invalid time sends error delegate")
    func startSessionInvalidTime() async {
        let store = await TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "invalid"
            )
        ) {
            PreparationFeature()
        }
        
        await store.send(.startButtonTapped)
        await store.receive(.delegate(.sessionFailedToStart(.invalidInput(reason: "Please enter a valid time in minutes"))))
    }
    
    @Test("Start session with zero time sends error delegate")
    func startSessionZeroTime() async {
        let store = await TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "0"
            )
        ) {
            PreparationFeature()
        }
        
        await store.send(.startButtonTapped)
        await store.receive(.delegate(.sessionFailedToStart(.invalidInput(reason: "Please enter a valid time in minutes"))))
    }
    
    @Test("Start session with RustCoreError sends error delegate")
    func startSessionRustCoreError() async {
        let store = await TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.rustCoreClient.start = { _, _ in
                throw RustCoreError.binaryNotFound
            }
        }
        
        await store.send(.startButtonTapped)
        await store.receive(.startSessionResponse(.failure(RustCoreError.binaryNotFound)))
        await store.receive(.delegate(.sessionFailedToStart(.rustCore(.binaryNotFound))))
    }
    
    @Test("Start session with generic error sends other error delegate")
    func startSessionGenericError() async {
        struct TestError: Error {
            let message = "Test error"
            var localizedDescription: String { message }
        }
        
        let store = await TestStore(
            initialState: PreparationFeature.State(
                goal: "Test goal",
                timeInput: "30"
            )
        ) {
            PreparationFeature()
        } withDependencies: {
            $0.rustCoreClient.start = { _, _ in
                throw TestError()
            }
        }
        
        await store.send(.startButtonTapped)
        await store.receive { action in
            guard case let .startSessionResponse(.failure(error)) = action else {
                return false
            }
            return error is TestError
        }
        await store.receive(.delegate(.sessionFailedToStart(.other("Test error"))))
    }
    
    @Test("Goal and time changes update state")
    func goalAndTimeChanges() async {
        let store = await TestStore(
            initialState: PreparationFeature.State()
        ) {
            PreparationFeature()
        }
        
        await store.send(.goalChanged("New goal")) {
            $0.goal = "New goal"
        }
        
        await store.send(.timeInputChanged("45")) {
            $0.timeInput = "45"
        }
    }
}