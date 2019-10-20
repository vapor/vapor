/// Combines two `Validator`s using AND logic, succeeding if both `Validator`s succeed without error.
public func && <T: Decodable>(lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    Validator.And(lhs: lhs, rhs: rhs).validator()
}

extension Validator {
    public struct And: ValidatorType {
        public enum Failure: ValidatorFailure {
            case left(ValidatorFailure)
            case right(ValidatorFailure)
            case both(left: ValidatorFailure, right: ValidatorFailure)
        }

        let lhs: Validator<T>
        let rhs: Validator<T>

        public init(lhs: Validator<T>, rhs: Validator<T>) {
            self.lhs = lhs
            self.rhs = rhs
        }

        public func validate(_ data: T) -> Failure? {
            switch (lhs.validate(data), rhs.validate(data)) {
            case (.none, .none): return nil
            case let (.some(left), .none): return .left(left)
            case let (.none, .some(right)): return .right(right)
            case let (.some(left), .some(right)): return .both(left: left, right: right)
            }
        }
    }
}

extension Validator.And.Failure: CustomStringConvertible {
    public var description: String {
        func describe(_ failure: ValidatorFailure, isLeft: Bool) -> String {
            (failure as? CustomStringConvertible)?.description
                ?? "\(isLeft ? "left" : "right") validation failed"
        }

        switch self {
        case let .left(failure):
            return describe(failure, isLeft: true)
        case let .right(failure):
            return describe(failure, isLeft: false)
        case let .both(left, right):
            return """
                \(describe(left, isLeft: true))\
                 and \
                \(describe(right, isLeft: false)))
                """
        }
    }
}
