/// Combines two `Validator`s using AND logic, succeeding if both `Validator`s succeed without error.
public func && <T: Decodable>(lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.And(lhs: lhs, rhs: rhs).validator()
}

extension Validator {

    /// `ValidatorResult` of "And" `Validator` that combines two `ValidatorResults`.
    /// If both results are successful the combined result is as well.
    public struct AndValidatorResult: ValidatorResult {

        /// `ValidatorResult` of left hand side of the "And" validation.
        public let left: ValidatorResult

        /// `ValidatorResult` of right hand side of the "And" validation.
        public let right: ValidatorResult

        /// See `CustomStringConvertible`.
        public var description: String {
            switch (left.failed, right.failed) {
            case (true, true),
                 (false, false):
                return "\(left) and \(right)"
            case (true, false):
                return left.description
            case (false, true):
                return right.description
            }
        }

        /// See `ValidatorResult`.
        public var failed: Bool { left.failed || right.failed }
    }

    struct And: ValidatorType {
        let lhs: Validator<T>
        let rhs: Validator<T>

        func inverted() -> Or {
            .init(lhs: lhs.inverted(), rhs: rhs.inverted())
        }

        func validate(_ data: T) -> AndValidatorResult {
            .init(left: lhs.validate(data), right: rhs.validate(data))
        }
    }
}
