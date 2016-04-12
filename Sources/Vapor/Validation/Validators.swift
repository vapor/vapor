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

public struct Validation {
    enum Error: ErrorProtocol {
        case FailedValidation(Any)
    }
}
public protocol Validator {
    associatedtype InputType: Validatable
    func test(input value: InputType) -> Bool
}

public protocol ValidationSuite: Validator {
    associatedtype InputType: Validatable
    static func test(input value: InputType) -> Bool
}

extension ValidationSuite {
    public func test(input value: InputType) -> Bool {
        return self.dynamicType.test(input: value)
    }
}

// MARK: Validated

class ContainsEmoji: ValidationSuite {
    static func test(input value: String) -> Bool {
        return true
    }
}
class AlreadyTaken: ValidationSuite {
    static func test(input value: String) -> Bool {
        return true
    }
}
class OwnedBy: Validator {
    init(user: String) {}
    func test(input value: String) -> Bool {
        return true
    }
}

public enum StringLength: Validator {
    case min(Int)
    case max(Int)
    case `in`(Range<Int>)

    public func test(input value: String) -> Bool {
        print("Testing: \(value)")
        let length = value.characters.count
        switch self {
        case .min(let m):
            return length >= m
        case .max(let m):
            return length <= m
        case .`in`(let range):
            return range ~= length
        }
    }
}

let user = ""

let available = !AlreadyTaken.self || OwnedBy(user: user)
let appropriateLength = StringLength.min(5) + StringLength.max(20)
let blename = try! "new name".validated(by: !ContainsEmoji.self + appropriateLength + available)
