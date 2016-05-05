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
    A struct representing a value that has passed Validation.

    This struct is intended to protect a value from existing
    that hasn't passed validation, allowing for a stronger 
    concept of `value safety`

    Value Safety is stricter when using validation suites, 
    but the flexible composition structure of validators
    allows for more complex validations.
*/
public struct Valid<V: Validator> {

    /// The underlying value that has passed validation
    public let value: V.InputType

    /**
        Valid initializer.

        As opposed to using this initializer, 
        it is more common to validate an object using:

         caller.validated(by: someValidator + SomeValidationSuite.self)

        - parameter value: the value to attempt initialization
        - parameter validator: the validator to use in evaluating the value

        - throws: an error if the value doesn't pass the validator
    */
    public init(_ value: V.InputType, by validator: V) throws {
        try self.value = value.tested(by: validator)
    }
}

extension Valid where V: ValidationSuite {


    /**
        Valid initializer.

        As opposed to using this initializer,
        it is more common to validate an object using:

         caller.validated(by: SomeValidationSuite.self)

        - parameter value: the value to attempt initialization
        - parameter validator: the validator to use in evaluating the value

        - throws: an error if the value doesn't pass the validator
    */
    public init(_ value: V.InputType, by suite: V.Type = V.self) throws {
        try self.value = value.tested(by: suite)
    }
}
