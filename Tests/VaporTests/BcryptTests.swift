import XCTest
import Vapor

final class BcryptTests: XCTestCase {
    func testVersion() throws {
        let digest = try Bcrypt.hash("foo", cost: 6)
        XCTAssert(digest.hasPrefix("$2b$06$"))
    }

    func testFail() throws {
        let digest = try Bcrypt.hash("foo", cost: 6)
        let res = try Bcrypt.verify("bar", created: digest)
        XCTAssertEqual(res, false)
    }

    func testInvalidMinCost() throws {
        XCTAssertThrowsError(try Bcrypt.hash("foo", cost: 1))
    }

    func testInvalidMaxCost() throws {
        XCTAssertThrowsError(try Bcrypt.hash("foo", cost: 32))
    }

    func testInvalidSalt() throws {
        do {
            _ = try Bcrypt.verify("", created: "foo")
            XCTFail("Should have failed")
        } catch let error as BcryptError {
            print(error)
        }
    }

    func testVerify() throws {
        for (desired, message) in tests {
            let result = try Bcrypt.verify(message, created: desired)
            XCTAssert(result, "\(message): did not match \(desired)")
        }
    }

    func testOnlineVapor() throws {
        let result = try Bcrypt.verify("vapor", created: "$2a$10$e.qg8zwKLHu3ur5rPF97ouzCJiJmZ93tiwNekDvTQfuhyu97QaUk.")
        XCTAssert(result, "verification failed")
    }
    
    func testBCryptService() throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = Application(test)
        defer { app.shutdown() }
        let hash = try app.passwordHashers.passwordHasher.hash("vapor")
        XCTAssertTrue(try BCryptDigest().verify("vapor", created: hash))
        
        let result = try app.passwordVerifiers.passwordVerifier.verify("vapor", created: hash)
        XCTAssertTrue(result)
    }
}

let tests: [(String, String)] = [
    ("$2a$05$CCCCCCCCCCCCCCCCCCCCC.E5YPO9kmyuRGyh0XouQYb4YMJKvyOeW", "U*U"),
    ("$2a$05$CCCCCCCCCCCCCCCCCCCCC.VGOzA784oUp/Z0DY336zx7pLYAy0lwK", "U*U*"),
    ("$2a$05$XXXXXXXXXXXXXXXXXXXXXOAcXxm9kjPGEMsLznoKqmqw7tc8WCx4a", "U*U*U"),
    ("$2a$05$abcdefghijklmnopqrstuu5s2v8.iXieOjg/.AySBTTZIIVFJeBui", "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789chars after 72 are ignored"),
    ("$2a$04$TI13sbmh3IHnmRepeEFoJOkVZWsn5S1O8QOwm8ZU5gNIpJog9pXZm", "vapor"),
    ("$2y$11$kHM/VXmCVsGXDGIVu9mD8eY/uEYI.Nva9sHgrLYuLzr0il28DDOGO", "Vapor3"),
    ("$2a$06$DCq7YPn5Rq63x1Lad4cll.TV4S6ytwfsfvkgY8jIucDrjc8deX1s.", ""),
    ("$2a$06$m0CrhHm10qJ3lXRY.5zDGO3rS2KdeeWLuGmsfGlMfOxih58VYVfxe", "a"),
    ("$2a$06$If6bvum7DFjUnE9p2uDeDu0YHzrHM6tf.iqN8.yx.jNN1ILEf7h0i", "abc"),
    ("$2a$06$.rCVZVOThsIa97pEDOxvGuRRgzG64bvtJ0938xuqzv18d3ZpQhstC", "abcdefghijklmnopqrstuvwxyz"),
    ("$2a$06$fPIsBO8qRqkjj273rfaOI.HtSV9jLDpTbZn782DC6/t7qT67P6FfO", "~!@#$%^&*()      ~!@#$%^&*()PNBFRD"),
]
