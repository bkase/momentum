import ComposableArchitecture
import Foundation
import Testing

@testable import MomentumApp

@MainActor
struct ActiveSessionFeatureTests {
    @Test
    func stopSession_Success() async {
        let store = TestStore(
            initialState: ActiveSessionFeature.State(
                goal: "Test goal",
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                expectedMinutes: 25
            )
        ) {
            ActiveSessionFeature()
        } withDependencies: {
            $0.rustCoreClient.stop = {
                "/test/reflection/path.md"
            }
        }

        await store.send(.performStop)
        await store.receive(.stopSessionResponse(.success("/test/reflection/path.md")))
        await store.receive(.delegate(.sessionStopped(reflectionPath: "/test/reflection/path.md")))
    }

    @Test
    func stopSession_Failure() async {
        struct TestError: Error, LocalizedError, Equatable {
            var errorDescription: String? { "Test error" }
        }

        let clock = TestClock()
        let store = TestStore(
            initialState: ActiveSessionFeature.State(
                goal: "Test goal",
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                expectedMinutes: 25
            )
        ) {
            ActiveSessionFeature()
        } withDependencies: {
            $0.rustCoreClient.stop = {
                throw TestError()
            }
            $0.continuousClock = clock
        }

        await store.send(.performStop)
        await store.receive(.stopSessionResponse(.failure(TestError()))) {
            $0.operationError = "Test error"
        }

        // Advance clock to trigger error dismissal
        await clock.advance(by: .seconds(5))
        await store.receive(.clearOperationError) {
            $0.operationError = nil
        }
    }
}
