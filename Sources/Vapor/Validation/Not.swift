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
    Use this to invert the logic of a Validator.
    This type can be created two ways

    1. Not.init(_:)

     Not(validatorToInvert)

    2. The `!` operator can be used to invert a validator

     !validatorToInvert
*/
public struct Not<V: Validator> {
    private typealias Validator = (input: V.InputType) throws -> Void
    private let validator: Validator

    /**
        Convenience only.

        Must stay private.
    */
    private init(_ validator: Validator) {
        self.validator = { value in
            do {
                try validator(input: value)
            } catch {
                return
            }
            /**
                We only arrive here if we passed validation.
                We can't throw in the `do` or it moves to catch.
            */
            throw Not<V>.error(with: value)
        }
    }
}

extension Not: Validator {
    /**
        Use this to validate with a `Not<T>` type.

        - parameter value: value to validate
    */
    public func validate(input value: V.InputType) throws {
        try validator(input: value)
    }
}

extension Not {

    /**
        Use this to invert a Validator

        - parameter lhs: the validator to invert
    */
    public init(_ lhs: V) {
        self.init(lhs.validate)
    }
}

extension Not where V: ValidationSuite {

    /**
        Use this to initialize with a ValidationSuite.

        - parameter lhs: validationSuite to initialize with. Can be inferred
    */
    public init(_ lhs: V.Type = V.self) {
        self.init(lhs.validate)
    }
}
