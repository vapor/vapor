extension Validator where T: OptionalType, T.WrappedType: Codable {
    /// Validates that the data is `nil`. Combine with the not-operator `!` to validate that the data is not `nil`.
    public static var `nil`: Validator<T.WrappedType?> {
        Nil<T.WrappedType>().validator()
    }
}

extension Validator {

    /// Validates that the data is `nil`.
    public struct Nil<T: Decodable>: ValidatorType {
        public struct Failure: ValidatorFailure {}

        /// See `Validator`.
        public func validate(_ data: T?) -> Failure? {
            data == nil ? nil : .init()
        }
    }
}

extension Validator.Nil.Failure: CustomStringConvertible {
    /// See `CustomStringConvertible`.
    public var description: String {
        "is not nil"
    }
}

