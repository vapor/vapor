/// Combines two `Validator`s using AND logic, succeeding if both `Validator`s succeed without error.
public func && <T: Decodable>(lhs: Validator<T>, rhs: Validator<T>) -> Validator<T> {
    .init {
        ValidatorResults.And(left: lhs.validate($0), right: rhs.validate($0))
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of "And" `Validator` that combines two `ValidatorResults`.
    /// If both results are successful the combined result is as well.
    public struct And {
        /// `ValidatorResult` of left hand side of the "And" validation.
        public let left: ValidatorResult

        /// `ValidatorResult` of right hand side of the "And" validation.
        public let right: ValidatorResult
    }
}

extension ValidatorResults.And: ValidatorResult {
    public var isFailure: Bool {
        self.left.isFailure || self.right.isFailure
    }
    
    public var successDescription: String? {
        switch (self.left.isFailure, self.right.isFailure) {
        case (false, false):
            return self.left.successDescription.flatMap { left in
                self.right.successDescription.map { right in
                    "\(left) and \(right)"
                }
            }
        default:
            return nil
        }
    }
    
    public var failureDescription: String? {
        switch (self.left.isFailure, self.right.isFailure) {
        case (true, true):
            return self.left.failureDescription.flatMap { left in
                self.right.failureDescription.map { right in
                    "\(left) and \(right)"
                }
            }
        case (true, false):
            return self.left.failureDescription
        case (false, true):
            return self.right.failureDescription
        default:
            return nil
        }
    }
    
    
}
