/// This protocol needs to be implemented in order to add a requirement to
/// a wrapped type.
/// Implementers receive the wrapped type and need to determine if its values
/// fulfill the requirements of the wrapper type.
/// ~~~
/// struct NonEmptyStringValidator: Validator {
///     static func validate(value: String) -> Bool {
///         return !value.isEmpty
///     }
/// }
/// ~~~
//
//
//public protocol _ComplexValidator {
//    associatedtype WrappedType
//    associatedtype ArgumentType // TODO: Better Name
//    static func validate(input value: WrappedType, with arg: ArgumentType) -> Bool
//}
//
//public protocol __SimpleValidator: _ComplexValidator {
//    // You'll have to do `typealias ArgumentType = Void`
//    static func validate(input value: WrappedType) -> Bool
//}
//
//extension __SimpleValidator {
//    static func validate(input value: WrappedType, with arg: ArgumentType) -> Bool {
//        return validate(input: value)
//    }
//}
//
////public protocol Validator {
////    associatedtype WrappedType
////
////    /// Validates if a value of the wrapped type fullfills the requirements of the
////    /// wrapper type.
////    ///
////    /// - parameter validate: An instance of the `WrappedType`
////    /// - returns: A `Bool` indicating success(`true`)/failure(`false`) of the validation
////    static func validate(value: WrappedType) -> Bool
////}
////
////
/////// Error that is thrown when a validation fails. Proivdes the validator type and
/////// the value that failed validation
////public struct ValidatorError: ErrorProtocol, CustomStringConvertible {
////    /// The value that failed validation.
////    public let wrapperValue: Any
////    /// Type of a specific `Validator`. `Any` is used because `Validator` has associated type requirements.
////    public let validator: Any.Type
////
////    public var description: String {
////        return "Value: '\(wrapperValue)' <\(wrapperValue.dynamicType)>, failed validation of Validator: \(validator.self)"
////    }
////}
//
//public struct StrLength: ComplexValidator {
//    public static func validate(input value: String, with arg: Int) -> Bool {
//        return value.characters.count > arg
//    }
//}
//
///// Wraps a type together with one validator. Provides a failable initializer
///// that will only return a value of `Validated` if the provided `WrapperType` value
///// fulfills the requirements of the specified `Validator`.
//public struct COMPLEX_Validated<V: _ComplexValidator> {
//    /// The value that passes the defined `Validator`.
//    ///
//    /// If you are able to access this property; it means the wrappedType passes the validator.
//    public let value: V.WrappedType
//
//    /// Throwing initializer that will *not* throw an error if the provided value fulfills the requirements
//    /// specified by the `Validator`.
//    public init(_ value: V.WrappedType, with argument: V.ArgumentType) throws {
//        guard V.validate(input: value, with: argument) else {
//            throw "back"
//        }
//
//        self.value = value
//    }
//
//    /// Failible initializer that will only succeed if the provided value fulfills the requirements specified by the `Validator`.
//    public init?(value: V.WrappedType, with argument: V.ArgumentType) {
//        try? self.init(value, with: argument)
//    }
//}
//
///// Validator wrapper which is valid when `V1` and `V2` validated to `true`.
//public struct And<
//    V1: Validator,
//    V2: Validator where
//V1.WrappedType == V2.WrappedType>: Validator {
//    public static func validate(value: V1.WrappedType) -> Bool {
//        return V1.validate(value) && V2.validate(value)
//    }
//}
//
///// Validator wrapper which is valid when either `V1` or `V2` validated to `true`.
//public struct Or<
//    V1: Validator,
//    V2: Validator where
//V1.WrappedType == V2.WrappedType>: Validator {
//    public static func validate(value: V1.WrappedType) -> Bool {
//        return V1.validate(value) || V2.validate(value)
//    }
//}
//
///// Validator wrapper which is valid when `V1` validated to `false`.
//public struct Not<V1: Validator>: Validator {
//    public static func validate(value: V1.WrappedType) -> Bool {
//        return !V1.validate(value)
//    }
//}
//
//// MARK: ----
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
////
//
///*
// Goal: Validator w/ Attributes
// Example: For string length, pass arg ie: 1,2,3 for length instead of validator for each
// Problem: Requires initializer, or static var to be safe
//*/
//public protocol __Validator {
//    associatedtype Wrapped
//    init()
////    func 
//}
//
//
//public struct ValidationEngine<T> {
//    typealias Validation = T -> Bool
//
//    var validations: [T -> Bool] = []
//
//    public init(_ validations: (T -> Bool)...) {
//        self.validations = validations
//    }
//
//    func makeValidated(with input: T) throws -> _Validated<T> {
//        for validation in validations where !validation(input) {
//            throw "your hands up"
//        }
//        return _Validated(input)
//    }
//}
//
//public struct _Validated<T> {
//    let value: T
//    private init(_ value: T) {
//        self.value = value
//    }
//}
//
//public struct ALT_Validated<T> {
//    typealias Validation = T -> Bool
//    typealias ValidatedFactory = T throws -> ALT_Validated
//
//    static func makeValidator(validations: Validation...) -> ValidatedFactory {
//        return { input in
//            for validation in validations where !validation(input) {
//                throw "ERR: your hands up"
//            }
//            return ALT_Validated(input)
//        }
//    }
//
//    public let value: T
//
//    private init(_ value: T) {
//        self.value = value
//    }
//}
//
//func + <T>(lhs: ALT_Validated<T>.ValidatedFactory, rhs: ALT_Validated<T>.ValidatedFactory) -> ALT_Validated<T>.ValidatedFactory {
//    return { input in
//        do {
//            let initialValidation = try lhs(input)
//            return try rhs(initialValidation.value)
//        } catch {
//            throw "ERR: both Didn't Work"
//        }
//    }
//}

//func + <V1: Validator, V2: Validator where V1.WrappedType == V2.WrappedType>(lhs: V1, rhs: V2) -> Validator {
//    return { input in
//        do {
//            let initialValidation = try lhs(input)
//            return try rhs(initialValidation.value)
//        } catch {
//            throw "ERR: both Didn't Work"
//        }
//    }
//}

//public typealias EmptyString = Validated<EmptyStringValidator>
//public typealias NotEmptyString = Validated<Not<EmptyStringValidator>>
//
//public struct EmptyStringValidator: Validator {
//    public static func validate(value: String) -> Bool {
//        return value.isEmpty
//    }
//}
//
//public struct StringLengthValidator: Validator {
//
//    public static func validate(value: String) -> Bool {
//        return true
//    }
//}
//
////public struct StringLengthValidator: Validator {
////
////}
//
//public protocol RequestInitializable {
//    init(_ request: Request) throws
//}
//
//public struct Example: RequestInitializable {
//    let name: NotEmptyString
//
//    public init(_ request: Request) throws {
//        name = try request.data.validated("name")
//    }
//}
//
