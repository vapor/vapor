//
//    The MIT License (MIT) Copyright (c) 2016 Benjamin Encz
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy of this 
//    software and associated documentation files (the "Software"), to deal in the Software 
//    without restriction, including without limitation the rights to use, copy, modify, merge, 
//    publish, distribute, sublicense, and/or sell copies of the Software, and to permit 
//    persons to whom the Software is furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all copies or 
//    substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
//    AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
//    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

/// A combination of two validators in which either one of them
/// can pass to be considered a successful validation
public final class Either<Input: Validatable>: Validator {
    let left: (Input) throws -> ()
    let right: (Input) throws -> ()

    internal init<L: Validator, R: Validator>(_ l: L, _ r: R) where L.Input == Input, R.Input == Input {
        left = l.validate
        right = r.validate
    }

    public func validate(_ input: Input) throws {
        guard let leftError = validate(input, with: left) else { return }
        guard let rightError = validate(input, with: right) else { return }
        throw error("neither validator passed '\(leftError)' and '\(rightError)'")
    }
}
