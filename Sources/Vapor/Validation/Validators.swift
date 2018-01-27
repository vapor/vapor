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
