import XCTest
@testable import Crypto

class BCryptTests: XCTestCase {
    static let allTests = [
        ("testVersion", testVersion),
        ("testFail", testFail),
        ("testSanity", testSanity),
        ("testInvalidSalt", testInvalidSalt),
        ("testVerify", testVerify)
    ]
    
    func testVersion() throws {
        let digest = try BCrypt.make(message: "foo", with: BCrypt.Salt(.two(.y), cost: 6, bytes: nil))
        XCTAssert(String(bytes: digest, encoding: .utf8)!.hasPrefix("$2y$06$"))
    }
    
    func testFail() throws {
        let salt = try BCrypt.Salt(.two(.y), cost: 6, bytes: nil)
        let digest = try BCrypt.make(message: "foo", with: salt)
        let res = try BCrypt.verify(message: "bar", matches: digest)
        XCTAssertEqual(res, false)
    }
    
    func testSanity() throws {
        let secret = "passwordpassword"
        
        let salt = try BCrypt.Salt(.two(.y), cost: 4, bytes: Data(secret.utf8))
        let res = try BCrypt.make(message: "foo", with: salt)
        
        let parser = try BCrypt.Parser(res)
        let parsedSalt = try parser.parseSalt()
        
        XCTAssertEqual(secret, String(bytes: parsedSalt.bytes, encoding: .utf8))
    }
    
    func testInvalidSalt() throws {
        do {
            _ = try BCrypt.Parser(Data("foo".utf8))
            XCTFail("Should have failed")
        } catch let error as BCrypt.Error {
            print(error)
        }
    }
    
    func testVerify() throws {
        for (desired, message) in tests {
            let result = try BCrypt.verify(message: message, matches: desired)
            XCTAssert(result, "Message '\(message)' did not create \(desired)")
        }
    }
}

let tests = [
    "$2a$04$TI13sbmh3IHnmRepeEFoJOkVZWsn5S1O8QOwm8ZU5gNIpJog9pXZm": "vapor",
    "$2a$06$DCq7YPn5Rq63x1Lad4cll.TV4S6ytwfsfvkgY8jIucDrjc8deX1s.": "",
    "$2a$06$m0CrhHm10qJ3lXRY.5zDGO3rS2KdeeWLuGmsfGlMfOxih58VYVfxe": "a",
    "$2a$06$If6bvum7DFjUnE9p2uDeDu0YHzrHM6tf.iqN8.yx.jNN1ILEf7h0i": "abc",
    "$2a$06$.rCVZVOThsIa97pEDOxvGuRRgzG64bvtJ0938xuqzv18d3ZpQhstC": "abcdefghijklmnopqrstuvwxyz",
    "$2a$06$fPIsBO8qRqkjj273rfaOI.HtSV9jLDpTbZn782DC6/t7qT67P6FfO": "~!@#$%^&*()      ~!@#$%^&*()PNBFRD"
]
