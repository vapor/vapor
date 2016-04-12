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

public struct And<
    V: Validator,
    U: Validator where V.InputType == U.InputType> {
    private typealias Closure = (input: V.InputType) -> Bool
    private let _test: Closure

    /**
     CONVENIENCE ONLY.

     MUST STAY PRIVATE
     */
    private init(_ lhs: Closure, _ rhs: Closure) {
        _test = { value in
            return lhs(input: value) && rhs(input: value)
        }
    }
}

extension And {
    public init(_ lhs: V, _ rhs: U) {
        self.init(lhs.test, rhs.test)
    }
}

extension And: Validator {
    public func test(input value: V.InputType) -> Bool {
        return _test(input: value)
    }
}

extension And where V: ValidationSuite {
    public init(_ lhs: V.Type = V.self, _ rhs: U) {
        self.init(lhs.test, rhs.test)
    }
}

extension And where U: ValidationSuite {
    public init(_ lhs: V, _ rhs: U.Type = U.self) {
        self.init(lhs.test, rhs.test)
    }
}

extension And where V: ValidationSuite, U: ValidationSuite {
    public init(_ lhs: V.Type = V.self, _ rhs: U.Type = U.self) {
        self.init(lhs.test, rhs.test)
    }
}
