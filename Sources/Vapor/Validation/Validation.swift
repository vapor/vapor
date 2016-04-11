extension String: ErrorProtocol {}

/*
 Possible Naming Conventions

 validated passes Tester -> Verified<T: Tester>
 validated passes TestSuite -> Verified<T: TestSuite>

 tested with (Self -> Bool) -> Self
 tested with Tester -> Self
 tested with TestSuite -> Self
 */

public protocol Validatable {}

// MARK: Validated Returns

extension Validatable {
    // MARK: Designated
    public func tested(@noescape passes tester: (input: Self) throws -> Bool) throws -> Self {
        guard try tester(input: self) else { throw "up" }
        return self
    }
}

// MARK: Validators

public protocol Validator {
    associatedtype InputType: Validatable
    func test(input value: InputType) throws -> Bool
}


extension Validatable {
    public func tested<T: Validator where T.InputType == Self>(passes tester: T) throws -> Self {
        return try tested(passes: tester.test)
    }

}

extension Optional where Wrapped: Validatable {
    public func tested(passes tester: (input: Wrapped) throws -> Bool) throws -> Wrapped {
        guard case .some(let value) = self else { throw "error" }
        return try value.tested(passes: tester)
    }

    public func tested<V: Validator where V.InputType == Wrapped>(passes validator: V) throws -> Wrapped {
        return try tested(passes: validator.test)
    }

    // TODO: Add validated(by: ` for optional versions
}

// MARK: Valiidation on Input

extension Validatable {
    public func validated<V: Validator where V.InputType == Self>(by validator: V) throws -> Validated<V> {
        return try Validated<V>(self, with: validator)
    }
    public func validated<S: ValidationSuite where S.InputType == Self>(by type: S.Type = S.self) throws -> Validated<S> {
        return try Validated<S>(self, with: S.self)
    }
}

extension Validatable {
    public func tested(passes collection: [(input: Self) throws -> Bool]) throws -> Self {
        for test in collection where !(try test(input: self)) {
            throw "up"
        }
        return self
    }

    public func tested<T: ValidationSuite where T.InputType == Self>(passes suite: T.Type) throws -> Self {
        guard try T.test(input: self) else { throw "up" }
        return self
    }
}


// MARK: Conformance

extension String: Validatable {}
extension Int: Validatable {}
extension Array: Validatable {}
extension Dictionary: Validatable {}

public protocol ValidationSuite: Validator {
    associatedtype InputType: Validatable
    static func test(input value: InputType) throws -> Bool
}

extension ValidationSuite {
    public func test(input value: InputType) throws -> Bool {
        return try self.dynamicType.test(input: value)
    }
}

// MARK: Validated

public struct Validated<V: Validator> {
    public let value: V.InputType

    public init(_ value: V.InputType, with validator: V) throws {
        try self.value = value.tested(passes: validator)
    }
}

extension Validated where V: ValidationSuite {
    public init(_ value: V.InputType, with suite: V.Type = V.self) throws {
        try self.value = value.tested(passes: suite)
    }
}

// MARK: Implementation Possiblities / Testing Ground

public enum StringLength: Validator {
    case min(Int)
    case max(Int)
    case `in`(Range<Int>)

    public func test(input value: String) throws -> Bool {
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

extension String {
    func tested(passes tester: StringLength) throws -> String {
        return try self.tested(passes: tester.test)
    }
}

public class EmailValidator: ValidationSuite {
    public static func test(input value: String) throws -> Bool {
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
    .tested(passes: .`in`(5...10))
    .tested(passes: { $0.characters.contains(nonAlphanumeric) })
    .tested(passes: { $0 != lastPassword })
    .tested(passes: DoesntContainUsername)


//try! "adsf".testWith(StringLength.min(5), DoesntContainUsername
//print("Val: \(val)")

/*
 Goals:
 - ValueSafety -- if possible
 - Composition
 - TypeSafety
 - Syntax
 */

//try! [1,2,3,4].tested(passes: { $0 == [1,2,3,4] })


// MARK: *************
// MARK: Composition

public struct CombinationTester<T: Validatable>: Validator {
    private let _test: (input: T) throws -> Bool

    private init<
        V1: Validator, V2: Validator
        where V1.InputType == V2.InputType, V1.InputType == T>
        (_ v1: V1, _ v2: V2) {

        self.init(v1.test, v2.test)
    }

    private init<V1: Validator where V1.InputType == T>(_ v1: V1, _ test: (input: T) throws -> Bool) {
        self.init(v1.test, test)
    }

    private init(_ lhs: (input: T) throws -> Bool, _ rhs: (input: T) throws -> Bool) {
        _test = { value in
            // TODO: Might be cleaner way
            return try (try lhs(input: value)) && (try rhs(input: value))
        }
    }

    public func test(input value: T) throws -> Bool {
        return try _test(input: value)
    }
}

func + <V1: Validator, V2: Validator where V1.InputType == V2.InputType>(lhs: V1, rhs: V2) -> CombinationTester<V1.InputType> {
    return CombinationTester(lhs, rhs)
}

func + <V1: Validator>(lhs: V1, rhs: V1.InputType throws -> Bool) -> CombinationTester<V1.InputType> {
    return CombinationTester(lhs, rhs)
}

func + <T: Validatable>(lhs: (input: T) throws -> Bool, rhs: (input: T) throws -> Bool) -> CombinationTester<T> {
    return CombinationTester(lhs, rhs)
}

