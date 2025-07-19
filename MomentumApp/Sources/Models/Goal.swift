import Foundation

struct Goal: Equatable, Hashable {
    let value: String

    init?(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.value = trimmed
    }

    var isEmpty: Bool {
        value.isEmpty
    }
}

extension Goal: CustomStringConvertible {
    var description: String {
        value
    }
}

extension Goal: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(value)!
    }
}
