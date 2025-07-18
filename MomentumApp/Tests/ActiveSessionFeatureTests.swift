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
        await store.receive(.delegate(.sessionStopped(reflectionPath: "/test/reflection/path.md")))
    }
    
    @Test
    func stopSession_Failure() async {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }
        
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
        }
        
        await store.send(.performStop)
        await store.receive(.delegate(.sessionFailedToStop(.other("Test error"))))
    }
}