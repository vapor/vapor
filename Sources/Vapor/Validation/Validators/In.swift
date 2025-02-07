extension Validator where T: Equatable & CustomStringConvertible {
    /// Validates whether an item is contained in the supplied array.
    public static func `in`(_ array: T...) -> Validator<T> {
        .in(array)
    }

    /// Validates whether an item is contained in the supplied sequence.
    public static func `in`<S>(_ sequence: S) -> Validator<T>
    where S: Sequence & Sendable, S.Element == T {
        .init {
            ValidatorResults.In(item: $0, items: .init(sequence))
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether an item is contained in the supplied sequence.
    public struct In<T> where T: Equatable & CustomStringConvertible & Sendable {
        /// Description of the item.
        public let item: T

        /// Descriptions of the elements of the supplied sequence.
        public let items: [T]
    }

}

extension ValidatorResults.In: ValidatorResult {
    public var isFailure: Bool {
        !self.items.contains(self.item)
    }

    public var successDescription: String? {
        self.makeDescription(not: false)
    }

    public var failureDescription: String? {
        self.makeDescription(not: true)
    }

    func makeDescription(not: Bool) -> String {
        let description: String
        switch self.items.count {
        case 1:
            description = self.items[0].description
        case 2:
            description = "\(self.items[0].description) or \(self.items[1].description)"
        default:
            let first = self.items[0..<(self.items.count - 1)]
                .map { $0.description }.joined(separator: ", ")
            let last = self.items[self.items.count - 1].description
            description = "\(first), or \(last)"
        }
        return "is\(not ? " not" : " ") \(description)"
    }
}
