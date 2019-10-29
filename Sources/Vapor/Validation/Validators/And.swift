/// Combines two `Validator`s using AND logic, succeeding if both `Validator`s succeed without error.
public func && <T: Decodable>(lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.And(lhs: lhs, rhs: rhs).validator()
}

extension Validator {
    // TODO: after hiding `ValidatorType`s, consider merging this with Or to create on LogicValidator that takes an operator like `&&`, `||` to reduce code duplication
    public struct And: ValidatorType {
        public struct Result: ValidatorResult {
            public let left: ValidatorResult
            public let right: ValidatorResult

            /// See `CustomStringConvertible`.
            public var description: String {
                "\(left.failed ? "not " : "")\(left) and \(right.failed ? "not " : "")\(right)"
            }

            /// See `ValidatorResult`.
            public var failed: Bool { left.failed || right.failed }
        }

        let lhs: Validator<T>
        let rhs: Validator<T>

        public init(lhs: Validator<T>, rhs: Validator<T>) {
            self.lhs = lhs
            self.rhs = rhs
        }

        public func validate(_ data: T) -> Result {
            .init(left: lhs.validate(data), right: rhs.validate(data))
        }
    }
}
