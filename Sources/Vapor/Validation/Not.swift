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

public struct Not<V: Validator> {
    private typealias Validator = (input: V.InputType) throws -> Void
    private let validator: Validator

    /**
     CONVENIENCE ONLY.

     MUST STAY PRIVATE
     */
    private init(_ validator: Validator) {
        self.validator = { value in
            do {
                try validator(input: value)
                throw Not<V>.error
            } catch {}
        }
    }
}

extension Not: Validator {
    public func validate(input value: V.InputType) throws {
        try validator(input: value)
    }
}

extension Not {
    public init(_ lhs: V) {
        self.init(lhs.validate)
    }
}

extension Not where V: ValidationSuite {
    public init(_ lhs: V.Type = V.self) {
        self.init(lhs.validate)
    }
}
