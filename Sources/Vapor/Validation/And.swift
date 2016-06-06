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
    This struct is used to encompass multiple Validators into one entity.

    It is possible to access this struct directly using 
     
     Both(validatorOne, validatorTwo)

    But it is more common to create And objects using the `+` operator:
     
     validatorOne + validatorTwo
*/
public struct Both<
    V: Validator,
    U: Validator where V.InputType == U.InputType> {
    private typealias Validator = (input: V.InputType) throws -> Void
    private let validator: Validator

    /**
        Convenience only.

        Must stay private.
    */
    private init(_ lhs: Validator, _ rhs: Validator) {
        validator = { value in
            try lhs(input: value)
            try rhs(input: value)
        }
    }
}

extension Both: Validator {
    /**
        Validator conformance that allows the 'And' struct
        to concatenate multiple Validator types.

        - parameter value: the value to validate

        - throws: an error on failed validation
    */
    public func validate(input value: V.InputType) throws {
        try validator(input: value)
    }
}

extension Both {
    /**
        Used to combine two Validator types
    */
    public init(_ lhs: V, _ rhs: U) {
        self.init(lhs.validate, rhs.validate)
    }
}

extension Both where V: ValidationSuite {
    /**
        Used to combine two Validator types where one is a ValidationSuite
    */
    public init(_ lhs: V.Type = V.self, _ rhs: U) {
        self.init(lhs.validate, rhs.validate)
    }
}

extension Both where U: ValidationSuite {
    /**
        Used to combine two Validators where one is a ValidationSuite
    */
    public init(_ lhs: V, _ rhs: U.Type = U.self) {
        self.init(lhs.validate, rhs.validate)
    }
}

extension Both where V: ValidationSuite, U: ValidationSuite {
    /**
        Used to combine two ValidationSuite types
    */
    public init(_ lhs: V.Type = V.self, _ rhs: U.Type = U.self) {
        self.init(lhs.validate, rhs.validate)
    }
}
