import XCTest
import Validation

class ValidationTests: XCTestCase {
    func testStringValidation() {
        expectError(Validator().assertNil("nil"))
        expectSuccess(Validator().assertNil(nil as String?))
        expectSuccess(Validator().assertNotNil("nil"))
        expectError(Validator().assertNotNil(nil as String?))
    }
    
    func testBooleans() {
        expectSuccess(Validator().assertTrue(true))
        expectError(Validator().assertFalse(true))
        expectError(Validator().assertTrue(false))
        expectSuccess(Validator().assertFalse(false))
    }
    
    func testAssert() {
        expectSuccess(Validator().assert(nil))
    }
    
    func testValidatable() throws {
        let user0 = User(email: "test@example.com", awesome: true)
        let user1 = User(email: "test@example.s", awesome: true)
        let user2 = User(email: "test@example.com", awesome: false)
        let user3 = User(email: "test@example.s", awesome: false)
        
        XCTAssertNoThrow(try user0.assertValid())
        XCTAssertThrowsError(try user1.assertValid())
        XCTAssertThrowsError(try user2.assertValid())
        XCTAssertThrowsError(try user3.assertValid())
        
        var validator = Validator()
        try validator.validate(user0)
        XCTAssert(validator.errors.count == 0)
        
        validator = Validator()
        try validator.validate(user1)
        XCTAssert(validator.errors.count == 1)
        
        validator = Validator()
        try validator.validate(user2)
        XCTAssert(validator.errors.count == 1)
        
        validator = Validator()
        try validator.validate(user3)
        XCTAssert(validator.errors.count == 2)
    }
    
    func testEmailValidation() {
        expectSuccess(Validator().assertEmail("test@example.com"))
        expectSuccess(Validator().assertEmail("test@example.co"))
        expectSuccess(Validator().assertEmail("test@example.email"))
        expectError(Validator().assertEmail("test@example.c"))
        expectError(Validator().assertEmail("test@example.s"))
        expectError(Validator().assertEmail("@example.com"))
        expectError(Validator().assertEmail("\\@example.com"))
        expectError(Validator().assertEmail("test@example.\\\\\\"))
    }
    
    func expectError(_ error: ErrorMessage?) {
        XCTAssertNotNil(error)
    }
    
    func expectSuccess(_ error: ErrorMessage?) {
        XCTAssertNil(error)
    }
    
    static var allTests = [
        ("testStringValidation", testStringValidation),
        ("testBooleans", testBooleans),
        ("testAssert", testAssert),
        ("testValidatable", testValidatable),
        ("testEmailValidation", testEmailValidation),
    ]
}

struct User : Validatable {
    var email: String
    var awesome: Bool
    
    func validate(loggingTo validator: Validator) throws {
        validator.assertEmail(email)
        validator.assertTrue(awesome)
    }
}
