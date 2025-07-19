import Foundation

struct Minutes: Equatable, Hashable {
    let value: Int

    init(_ value: Int) {
        precondition(value > 0, "Minutes must be positive")
        self.value = value
    }

    init?(string: String) {
        guard let intValue = Int(string), intValue > 0 else {
            return nil
        }
        self.value = intValue
    }

    var asUInt64: UInt64 {
        UInt64(value)
    }

    var asTimeInterval: TimeInterval {
        TimeInterval(value * 60)
    }
}

extension Minutes: CustomStringConvertible {
    var description: String {
        "\(value) min"
    }
}
