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

public protocol Validator: ErrorProtocol {
    associatedtype InputType: Validatable
    func validate(input value: InputType) throws
}

public protocol ValidationSuite: Validator {
    associatedtype InputType: Validatable
    static func validate(input value: InputType) throws
}

extension ValidationSuite {
    public func validate(input value: InputType) throws {
        try self.dynamicType.validate(input: value)
    }
}

// MARK: Validated

class ContainsEmoji: ValidationSuite {
    static func validate(input value: String) throws {
        // pass
    }
}

class AlreadyTaken: ValidationSuite {
    static func validate(input value: String) throws {
        // pass
    }
}

class OwnedBy: Validator {
    init(user: String) {}
    func validate(input value: String) throws {
        // pass
    }
}

let user = ""

let available = !AlreadyTaken.self || OwnedBy(user: user)
let appropriateLength = StringLength.min(5) + StringLength.max(20)
let blename = try! "new name".validated(by: !ContainsEmoji.self + appropriateLength + available)
