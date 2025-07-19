import ComposableArchitecture
import Foundation
import Testing

@testable import MomentumApp

@MainActor
struct ReflectionFeatureTests {
    @Test
    func analyzeReflection_Success() async {
        let analysisResult = AnalysisResult(
            summary: "Test summary",
            suggestion: "Test suggestion",
            reasoning: "Test reasoning"
        )

        let store = TestStore(
            initialState: ReflectionFeature.State(
                reflectionPath: "/test/reflection.md"
            )
        ) {
            ReflectionFeature()
        } withDependencies: {
            $0.rustCoreClient.analyze = { _ in
                analysisResult
            }
        }

        await store.send(.analyzeButtonTapped)
        await store.receive(.analyzeResponse(.success(analysisResult)))
        await store.receive(.delegate(.analysisRequested(analysisResult: analysisResult)))
    }

    @Test
    func analyzeReflection_Failure() async {
        struct TestError: Error, LocalizedError, Equatable {
            var errorDescription: String? { "Test error" }
        }

        let clock = TestClock()
        let store = TestStore(
            initialState: ReflectionFeature.State(
                reflectionPath: "/test/reflection.md"
            )
        ) {
            ReflectionFeature()
        } withDependencies: {
            $0.rustCoreClient.analyze = { _ in
                throw TestError()
            }
            $0.continuousClock = clock
        }

        await store.send(.analyzeButtonTapped)
        await store.receive(.analyzeResponse(.failure(TestError()))) {
            $0.operationError = "Test error"
        }

        // Advance clock to trigger error dismissal
        await clock.advance(by: .seconds(5))
        await store.receive(.clearOperationError) {
            $0.operationError = nil
        }
    }

    @Test
    func cancelReflection() async {
        let store = TestStore(
            initialState: ReflectionFeature.State(
                reflectionPath: "/test/reflection.md"
            )
        ) {
            ReflectionFeature()
        }

        await store.send(.cancelButtonTapped)
    }
}
