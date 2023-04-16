/// Combines two `Validator`s, succeeding if either of the `Validator`s does not fail.
public func ||<T> (lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    .init {
        ValidatorResults.Or(left: lhs.validate($0), right: rhs.validate($0))
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of "Or" `Validator` that combines two `ValidatorResults`.
    /// If either result is successful the combined result is as well.
    public struct Or: Sendable {
        /// `ValidatorResult` of left hand side.
        public let left: ValidatorResult

        /// `ValidatorResult` of right hand side.
        public let right: ValidatorResult
    }
}

extension ValidatorResults.Or: ValidatorResult {
    public var isFailure: Bool {
        self.left.isFailure && self.right.isFailure
    }
    
    public var successDescription: String? {
        switch (self.left.isFailure, self.right.isFailure) {
        case (false, false):
            return self.left.successDescription.flatMap { left in
                self.right.successDescription.map { right in
                    "\(left) and \(right)"
                }
            }
        case (true, false):
            return self.right.successDescription
        case (false, true):
            return self.left.successDescription
        default:
            return nil
        }
    }
    
    public var failureDescription: String? {
        switch (left.isFailure, right.isFailure) {
        case (true, true):
            return left.failureDescription.flatMap { left in
                right.failureDescription.map { right in
                    "\(left) and \(right)"
                }
            }
        default:
            return nil
        }
    }
}
