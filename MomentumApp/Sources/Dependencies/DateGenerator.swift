import ComposableArchitecture
import Foundation

struct DateGenerator: DependencyKey {
    var now: @Sendable () -> Date
    var timestamp: @Sendable () -> TimeInterval

    static let liveValue = Self(
        now: { Date() },
        timestamp: { Date().timeIntervalSince1970 }
    )

    static let testValue = Self(
        now: { Date(timeIntervalSince1970: 1_700_000_000) },
        timestamp: { 1_700_000_000 }
    )
}

extension DependencyValues {
    var date: DateGenerator {
        get { self[DateGenerator.self] }
        set { self[DateGenerator.self] = newValue }
    }
}
