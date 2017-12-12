import Validation
import XCTest

class ValidationTests: XCTestCase {
    func testValidate() throws {
        let user = User(name: "Tanner", age: 23)
        user.child = User(name: "Zizek Pulaski", age: 3)
        do {
            try user.validate()
        } catch {
            XCTFail("\(error)")
        }
    }

    func testASCII() throws {
        try IsASCII().validate(.string("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
        do {
            try IsASCII().validate(.string("ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
            XCTFail()
        } catch is ValidationError {
            // pass
        }
    }

    func testAlphanumeric() throws {
        try IsAlphanumeric().validate(.string("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"))
        do {
            try IsAlphanumeric().validate(.string("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
            XCTFail()
        } catch is ValidationError {
            // pass
        }
    }

    func testEmail() throws {
        try IsEmail().validate(.string("tanner@vapor.codes"))
        do {
            try IsEmail().validate(.string("asdf"))
            XCTFail()
        } catch is ValidationError {
            // pass
        }
    }

    static var allTests = [
        ("testValidate", testValidate),
        ("testASCII", testASCII),
        ("testAlphanumeric", testAlphanumeric),
        ("testEmail", testEmail),
    ]
}

final class User: Validatable {
    var id: Int?
    var name: String
    var age: Int
    var child: User?

    init(id: Int? = nil, name: String, age: Int) {
        self.id = id
        self.name = name
        self.age = age
    }
    
    static var validations: Validations = [
        key(\.name): IsCount(5...),
        key(\.age): IsCount(3...),
        key(\.child): IsNil() || IsValid()
    ]
}
