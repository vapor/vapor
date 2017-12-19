import Validation
import XCTest

class ValidationTests: XCTestCase {
    func testValidate() throws {
        let user = User(name: "Tanner", age: 23)
        user.child = User(name: "Zizek Pulaski", age: 3)
        try user.validate()
    }

    func testASCII() throws {
        try IsASCII().validate(.string("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
        XCTAssertThrowsError(try IsASCII().validate(.string("ABCDEFGHIJKLMNOPQR🤠STUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))) {
            XCTAssert($0 is ValidationError)
        }
    }

    func testAlphanumeric() throws {
        try IsAlphanumeric().validate(.string("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"))
        XCTAssertThrowsError(try IsAlphanumeric().validate(.string("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))) {
            XCTAssert($0 is ValidationError)
        }
    }

    func testEmail() throws {
        try IsEmail().validate(.string("tanner@vapor.codes"))
        XCTAssertThrowsError(try IsEmail().validate(.string("asdf"))) { XCTAssert($0 is ValidationError) }
    }
    
    func testCount() throws {
        try IsCount(-5...5).validate(.int(4))
        try IsCount(-5...5).validate(.int(5))
        try IsCount(-5...5).validate(.int(-5))
        XCTAssertThrowsError(try IsCount(-5...5).validate(.int(6))) { XCTAssert($0 is ValidationError) }
        XCTAssertThrowsError(try IsCount(-5...5).validate(.int(-6))) { XCTAssert($0 is ValidationError) }

        try IsCount(5...).validate(.uint(UInt.max))
        try IsCount(...(UInt.max - 100)).validate(.int(Int.min))
        
        XCTAssertThrowsError(try IsCount(...Int.max).validate(.uint(UInt.max))) { XCTAssert($0 is ValidationError) }

        try IsCount(-5...5).validate(.uint(4))
        XCTAssertThrowsError(try IsCount(-5...5).validate(.uint(6))) { XCTAssert($0 is ValidationError) }
        
        try IsCount(-5..<6).validate(.int(-5))
        try IsCount(-5..<6).validate(.int(-4))
        try IsCount(-5..<6).validate(.int(5))
        XCTAssertThrowsError(try IsCount(-5..<6).validate(.int(-6))) { XCTAssert($0 is ValidationError) }
        XCTAssertThrowsError(try IsCount(-5..<6).validate(.int(6))) { XCTAssert($0 is ValidationError) }
    }
    
    static var allTests = [
        ("testValidate", testValidate),
        ("testASCII", testASCII),
        ("testAlphanumeric", testAlphanumeric),
        ("testEmail", testEmail),
        ("testCount", testCount),
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
