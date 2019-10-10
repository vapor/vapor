///// Inverts a `Validation`.
//public prefix func !<T: Decodable> (validator: Validator<T>) -> Validator<T> {
//    NotValidator(validator: validator).validator()
//}
//
//public struct NotValidatorFailure<F: ValidatorFailure>: ValidatorFailure {
//    let type: F.Type = F.self
//}
//
//
//
///// Inverts a validator
//struct NotValidator<T: Decodable>: ValidatorType {
//    /// See `ValidatorType`.
//
//    /// The inverted `Validator`.
//    let validator: Validator<T>
//
//    /// See `ValidatorType`
//    func validate(_ data: T) -> NotValidatorFailure<Failure>? {
//        validator.validate(data) == nil ? .init() : nil
//    }
//}
