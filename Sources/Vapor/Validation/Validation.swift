@_exported import Validated

// TODO: This is temporary to speed up dev, use real errors before :ship:
extension String: ErrorProtocol {}

public protocol ComplexValidator: Validator {
    associatedtype WrappedType
    associatedtype ArgumentType // TODO: Better Name
    static func validate(input value: WrappedType, with arg: ArgumentType) -> Bool
}

extension ComplexValidator {
    static func validate(string: WrappedType) -> Bool {
        fatalError("Complex validators required to use argument type")
    }
}
//extension ComplexValidator {
//    static func validate(value: WrappedType) -> Bool {
//        return false // TODO: Not sure what to do w/ this maybe fatalerror()?
//    }
//}

final class StringLength: ComplexValidator {
    static func validate(input string: String, with arg: Int) -> Bool {
        return string.characters.count > arg
    }
}

//public class MiddleMan<T: ComplexValidator> {
//    let input: T.WrappedType
//
//    private init(_ input: T.WrappedType) {
//        self.input = input
//    }
//
//    func with(parameters: T.ArgumentType) throws -> Validated<T> {
//        guard T.validate(input: input, with: parameters) else {
//            throw "up"
//        }
//        return Validated(input)
//    }
//}


protocol VapValidatable {}
extension VapValidatable {
    func validatedWith<T: Validator where T.V == Self>(validator: T) throws -> Self {
        return try validator.validate(input: self)
    }
}

protocol Validator {
    associatedtype V: VapValidatable

    func validate(input value: V) throws -> V
}

extension Request.Content {
//    public func __validated<T>(key: String) throws -> T {
//        guard let val = self[key] else { throw "" }
//
//    }

    public func validated<ValidatorType: Validator>(key: String) throws -> Validated<ValidatorType> {
        guard let val = self[key] else {
            throw "no value"
        }

        // It's going to be Node so 'String' or 'Json'. We need to constrain `Wrapped` type to `Node` convertible
        // Propose to Tanner that query is also Json and => `[String : .string(value)]`. This will be easier for users to map
        // Mapping should be fuzzy.
        guard let input = val as? ValidatorType.WrappedType else {
            throw "not correct input type"
        }

        return try Validated<ValidatorType>(input)
    }


    public func __validated<ValidatorType: _ComplexValidator>(key: String, with arg: ValidatorType.ArgumentType) throws -> COMPLEX_Validated<ValidatorType> {
        guard let val = self[key] else {
            throw "no value"
        }

        // It's going to be Node so 'String' or 'Json'. We need to constrain `Wrapped` type to `Node` convertible
        // Propose to Tanner that query is also Json and => `[String : .string(value)]`. This will be easier for users to map
        // Mapping should be fuzzy.
        guard let input = val as? ValidatorType.WrappedType else {
            throw "not correct input type"
        }

        return try COMPLEX_Validated<ValidatorType>(input, with: arg)
    }

//    public func validated<InputType>(key: String) throws -> ALT_Validated<InputType> {
//        throw "ERR: "
//        guard let val = self[key] else {
//            throw "no value"
//        }
//
//        // It's going to be Node so 'String' or 'Json'. We need to constrain `Wrapped` type to `Node` convertible
//        // Propose to Tanner that query is also Json and => `[String : .string(value)]`. This will be easier for users to map
//        // Mapping should be fuzzy.
//        guard let input = val as? ValidatorType.WrappedType else {
//            throw "not correct input type"
//        }
//
//        return try Validated<ValidatorType>(input)
//    }
}
