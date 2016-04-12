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
    private typealias Closure = (input: V.InputType) -> Bool
    private let _test: Closure

    /**
     CONVENIENCE ONLY.

     MUST STAY PRIVATE
     */
    private init(_ v1: Closure) {
        _test = { value in !v1(input: value) }
    }
}

extension Not: Validator {
    public func test(input value: V.InputType) -> Bool {
        return _test(input: value)
    }
}

extension Not {
    public init(_ lhs: V) {
        self.init(lhs.test)
    }
}


extension Not where V: ValidationSuite {
    public init(_ lhs: V.Type = V.self) {
        self.init(lhs.test)
    }
}
