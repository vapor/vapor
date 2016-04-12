extension String: ErrorProtocol {}

/*
 Possible Naming Conventions

 validated by Tester -> Verified<T: Tester>
 validated by TestSuite -> Verified<T: TestSuite>

 tested by (Self -> Bool) -> Self
 tested by Tester -> Self
 tested by TestSuite -> Self
 */

// MARK: Validators

public protocol Validator {
    associatedtype InputType: Validatable
    func test(input value: InputType) -> Bool
}

public protocol ValidationSuite: Validator {
    associatedtype InputType: Validatable
    static func test(input value: InputType) -> Bool
}

extension ValidationSuite {
    public func test(input value: InputType) -> Bool {
        return self.dynamicType.test(input: value)
    }
}

// MARK: Validatable

public protocol Validatable {}

// MARK: Conformance

extension String: Validatable {}

extension Set: Validatable {}
extension Array: Validatable {}
extension Dictionary: Validatable {}

extension Int: Validatable {}
extension Int8: Validatable {}
extension Int16: Validatable {}
extension Int32: Validatable {}
extension Int64: Validatable {}

extension UInt: Validatable {}
extension UInt8: Validatable {}
extension UInt16: Validatable {}
extension UInt32: Validatable {}
extension UInt64: Validatable {}

extension Float: Validatable {}
extension Double: Validatable {}

// MARK: Testing

extension Validatable {
    public func tested(@noescape by tester: (input: Self) throws -> Bool) throws -> Self {
        guard try tester(input: self) else { throw "up" }
        return self
    }

    public func tested<V: Validator where V.InputType == Self>(by tester: V) throws -> Self {
        return try tested(by: tester.test)
    }

    public func tested<S: ValidationSuite where S.InputType == Self>(by tester: S.Type) throws -> Self {
        return try tested(by: tester.test)
    }

}

extension Optional where Wrapped: Validatable {
    public func tested(@noescape by tester: (input: Wrapped) throws -> Bool) throws -> Wrapped {
        guard case .some(let value) = self else { throw "error" }
        return try value.tested(by: tester)
    }

    public func tested<V: Validator where V.InputType == Wrapped>(by validator: V) throws -> Wrapped {
        return try tested(by: validator.test)
    }

    public func tested<S: ValidationSuite where S.InputType == Wrapped>(by suite: S.Type) throws -> Wrapped {
        return try tested(by: suite.test)
    }
}

// MARK: Validation

extension Validatable {
    public func validated<V: Validator where V.InputType == Self>(by validator: V) throws -> Validated<V> {
        return try Validated<V>(self, by: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Self>(by type: S.Type = S.self) throws -> Validated<S> {
        return try Validated<S>(self, by: S.self)
    }
}

extension Optional where Wrapped: Validatable {
    public func validated<V: Validator where V.InputType == Wrapped>(by validator: V) throws -> Validated<V> {
        guard case .some(let value) = self else { throw "error" }
        return try Validated<V>(value, by: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Wrapped>(by type: S.Type = S.self) throws -> Validated<S> {
        guard case .some(let value) = self else { throw "error" }
        return try Validated<S>(value, by: S.self)
    }
}

// MARK: Validated

public struct Validated<V: Validator> {
    public let value: V.InputType

    public init(_ value: V.InputType, by validator: V) throws {
        try self.value = value.tested(by: validator)
    }
}

extension Validated where V: ValidationSuite {
    public init(_ value: V.InputType, by suite: V.Type = V.self) throws {
        try self.value = value.tested(by: suite)
    }
}

// MARK: Implementation Possiblities / Testing Ground

public enum StringLength: Validator {
    case min(Int)
    case max(Int)
    case `in`(Range<Int>)

    public func test(input value: String) -> Bool {
        print("Testing: \(value)")
        let length = value.characters.count
        switch self {
        case .min(let m):
            return length >= m
        case .max(let m):
            return length <= m
        case .`in`(let range):
            return range ~= length
        }
    }
}

public class EmailValidator: ValidationSuite {
    public static func test(input value: String) -> Bool {
        return true
    }
}

public typealias EmailAddress = Validated<EmailValidator>

let name = try! "*****".validated(by: StringLength.min(5))
let emailExplicit: EmailAddress = try! "joe@google.com".validated()
let emailInferred = try! "joe@google.com".validated(by: EmailValidator.self)

/*
 Chain Validators to create Validated<And<Original, New>>
 */

//struct _Tester<T: Testable> {
//
//
//
//    static func makeWith<ValidatorType: Validator where ValidatorType.ValidationType == T>(validator: ValidatorType) -> _Tester {
//        return
//    }
//}

public struct TestableNamespace {}

func nonAlphanumeric(char: Character) -> Bool { return true }
let lastPassword = ""

let DoesntContainUsername: String -> Bool = { _ in return true }
let val = try? "password"
    .tested(by: StringLength.`in`(5...10))
    .tested(by: { $0.characters.contains(nonAlphanumeric) })
    .tested(by: { $0 != lastPassword })
    .tested(by: DoesntContainUsername)


//try! "adsf".testWith(StringLength.min(5), DoesntContainUsername
//print("Val: \(val)")

/*
 Goals:
 - ValueSafety -- if possible
 - Composition
 - TypeSafety
 - Syntax
 */

//try! [1,2,3,4].tested(by: { $0 == [1,2,3,4] })

// MARK: And

public struct And<
    V1: Validator,
    V2: Validator where V1.InputType == V2.InputType>: Validator {

    private let _validate: V1.InputType -> Bool
    init(_ v1: V1, _ v2: V2) {
        _validate = { value in
            return v1.test(input: value) && v2.test(input: value)
        }
    }

    public func test(input value: V1.InputType) -> Bool {
        return _validate(value)
    }
}

extension And where V1: ValidationSuite {
    init(_ v1: V1.Type = V1.self, _ v2: V2) {
        _validate = { value in
            return v1.test(input: value) && v2.test(input: value)
        }
    }
}

extension And where V2: ValidationSuite {
    init(_ v1: V1, _ v2: V2.Type = V2.self) {
        _validate = { value in
            return v1.test(input: value) && v2.test(input: value)
        }
    }
}

extension And where V1: ValidationSuite, V2: ValidationSuite {
    init(_ v1: V1.Type = V1.self, _ v2: V2.Type = V2.self) {
        _validate = { value in
            return v1.test(input: value) && v2.test(input: value)
        }
    }
}

// MARK: Or

/*
 Using `Or` and `Not` while also using `throws` gets really strange. 
 Is an error the right decision here, or should we just have `-> Bool`
 as not throwing
 
 The issue is if it throws, is it equivelant to a `false` logically? If so, just have false
 */

public struct Or<
    V1: Validator,
    V2: Validator where V1.InputType == V2.InputType>: Validator {
    private let _test: V1.InputType -> Bool

    private init(_ v1: V1.InputType -> Bool, _ v2: V2.InputType -> Bool) {
        _test = { value in
            return v1(value) || v2(value)
        }
    }

    init(_ v1: V1, _ v2: V2) {
        self.init(v1.test, v2.test)
    }

    public func test(input value: V1.InputType) -> Bool {
        return _test(value)
    }
}


extension Or where V1: ValidationSuite {
    init(_ v1: V1.Type = V1.self, _ v2: V2) {
        self.init(v1.test, v2.test)
    }
}

extension Or where V2: ValidationSuite {
    init(_ v1: V1, _ v2: V2.Type = V2.self) {
        self.init(v1.test, v2.test)
    }
}

extension Or where V1: ValidationSuite, V2: ValidationSuite {
    init(_ v1: V1.Type = V1.self, _ v2: V2.Type = V2.self) {
        self.init(v1.test, v2.test)
    }
}

// MARK: Not

public struct Not<V1: Validator>: Validator {
    private let _test: V1.InputType -> Bool

    // MARK: Internal convenience ONLY Do not change PRIVATE
    private init(_ v1: V1.InputType -> Bool) {
        _test = { value in !v1(value) }
    }

    init(_ v1: V1) {
        self.init(v1.test)
    }

    public func test(input value: V1.InputType) -> Bool {
        return _test(value)
    }
}


extension Not where V1: ValidationSuite {
    init(_ v1: V1.Type = V1.self) {
        self.init(v1.test)
    }
}

/*
 Or is much trickier w/ throwing and catching, needs rethinking
 */

// MARK: Not

// MAKR: Composition

func + <V1: Validator, V2: Validator where V1.InputType == V2.InputType>(lhs: V1, rhs: V2) -> And<V1, V2> {
    return And(lhs, rhs)
}
