/*
    The MIT License (MIT) Copyright (c) 2016 Benjamin Encz

    Permission is hereby granted, free of charge, to any person obtaining a copy of this
    software and associated documentation files (the "Software"), to deal in the Software
    without restriction, including without limitation the rights to use, copy, modify, merge,
    publish, distribute, sublicense, and/or sell copies of the Software, and to permit
    persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or
    substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
    AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

public protocol _Validatable {}

public protocol _Validator {
    associatedtype Input: _Validatable
    func validate(_ input: Input) throws
}

public enum _ValidationError: Error {
    case failures([Error])
}

public final class _ValidatorList<Input: _Validatable>: _Validator {
    public private(set) var validators: [(Input) throws -> Void] = []

    internal init() {}

    internal init<V: _Validator>(_ validator: V) where V.Input == Input {
        extend(validator)
    }

    internal func extend<V: _Validator>(_ v: V) where V.Input == Input {
        validators.append(v.validate)
    }

    internal func extend(_ v: @escaping (Input) throws -> Void) {
        validators.append(v)
    }

    public func validate(_ input: Input) throws {
        var failures = [Error]()

        validators.forEach { validator in
            do {
                try validator(input)
            } catch {
                failures.append(error)
            }
        }

        if !failures.isEmpty { throw _ValidationError.failures(failures) }
    }
}

extension _Validatable {
    public func validated<V: _Validator>(by validator: V) throws where V.Input == Self {
        let list = _ValidatorList(validator)
        try validated(by: list)
    }

    public func validated(by list: _ValidatorList<Self>) throws {
        try list.validate(self)
    }
}

func && <L: _Validator, R: _Validator>(lhs: L, rhs: R) -> _ValidatorList<L.Input> where L.Input == R.Input {
    let list = _ValidatorList<L.Input>()
    list.extend(lhs)
    list.extend(rhs)
    return list
}

func && <R: _Validator>(lhs: _ValidatorList<R.Input>, rhs: R) -> _ValidatorList<R.Input> {
    let list = _ValidatorList<R.Input>()
    lhs.validators.forEach(list.extend)
    list.extend(rhs)
    return list
}

func && <L: _Validator>(lhs: L, rhs: _ValidatorList<L.Input>) -> _ValidatorList<L.Input> {
    let list = _ValidatorList<L.Input>()
    rhs.validators.forEach(list.extend)
    list.extend(lhs)
    return list
}

func && <I: _Validatable>(lhs: _ValidatorList<I>, rhs: _ValidatorList<I>) -> _ValidatorList<I> {
    let list = _ValidatorList<I>()
    lhs.validators.forEach(list.extend)
    rhs.validators.forEach(list.extend)
    return list
}


public final class _OrValidator<Input: _Validatable>: _Validator {
    public enum OrError: Error {
        case failure(left: Error, right: Error)
    }

    let left: (Input) throws -> ()
    let right: (Input) throws -> ()

    internal init<L: _Validator, R: _Validator>(_ l: L, _ r: R) where L.Input == Input, R.Input == Input {
        left = l.validate
        right = r.validate
    }

    public func validate(_ input: Input) throws {
        guard let leftError = validate(input, with: left) else { return }
        // got left error, try right
        guard let rightError = validate(input, with: right) else { return }
        // neither passed, throw
        throw OrError.failure(left: leftError, right: rightError)
    }
}

extension _Validator {
    fileprivate func validate(_ input: Input, with validator: (Input) throws -> ()) -> Error? {
        do {
            try validator(input)
            return nil
        } catch {
            return error
        }
    }
}

public func || <L: _Validator, R: _Validator> (lhs: L, rhs: R) -> _OrValidator<L.Input> where L.Input == R.Input {
    return _OrValidator(lhs, rhs)
}

public final class _Not<Input: _Validatable>: _Validator {
    public enum NotError: Error {
        case expectedAnError
    }

    let validate: (Input) throws -> ()

    init<V: _Validator>(_ validator: V) where V.Input == Input {
        self.validate = validator.validate
    }

    public func validate(_ input: Input) throws {
        guard let _ = validate(input, with: validate) else { throw NotError.expectedAnError }
    }
}

public prefix func ! <V: _Validator>(validator: V) -> _Not<V.Input> {
    return _Not(validator)
}

/**
    The core validator, used for validations that require
    parameters. For example, a string length validator that
    uses a dynamic value to evaluate by.

     public enum StringLength: Validator {
         case min(Int)
         case max(Int)
         case containedIn(Range<Int>)

         public func validate(input value: String) throws {
             let length = value.characters.count
             switch self {
                case .min(let m) where length >= m:
                    break
                case .max(let m) where length <= m:
                    break
                case .containedIn(let range) where range ~= length:
                    break
                default:
                    throw error(with: value)
             }
         }
     }

    And used like:

        let validated = try "string".validated(by: StringLength.min(4))

*/
public protocol Validator {
    /**
        The type of value that this validator is capable
        of evaluating
    */
    associatedtype InputType: Validatable

    /**
        Used to validate a given input. Should throw
        error if validation fails using:

         throw error(with: value)

        A function that does not throw will be considered a pass.
    */
    func validate(input value: InputType) throws
}

public protocol ValidationSuite: Validator {
    /**
        The type of value that this validator is capable
        of evaluating
    */
    associatedtype InputType: Validatable

    /**
        Used to validate a given input. Should throw
        error if validation fails using:

         throw error(with: value)

        A function that does not throw will be considered a pass.
    */
    static func validate(input value: InputType) throws
}

extension ValidationSuite {
    /**
        ValidationSuite objects automatically conform to Validator
        by invoking the static validation

        - parameter value: input value to validate

        - throws: an error if validation fails
    */
    public func validate(input value: InputType) throws {
        try type(of: self).validate(input: value)
    }
}
