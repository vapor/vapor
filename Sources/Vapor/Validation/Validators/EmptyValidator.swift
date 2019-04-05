//extension Validator where T: Collection {
//    /// Validates that the data is empty. You can also check a non empty state by combining with the `NotValidator`
//    ///
//    ///     try validations.add(\.name, .empty)
//    ///     try validations.add(\.name, !.empty)
//    ///
//    public static var empty: Validator<T> {
//        return EmptyValidator().validator()
//    }
//}
//
//// MARK: Private
//
///// Validates whether the data is empty.
//fileprivate struct EmptyValidator<T>: ValidatorType where T: Collection {
//    /// See `ValidatorType`.
//    var validatorReadable: String {
//        return "empty"
//    }
//    
//    /// See `ValidatorType`.
//    func validate(_ data: T) throws {
//        guard data.isEmpty else {
//            throw BasicValidationError("is not empty")
//        }
//    }
//}
