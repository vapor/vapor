import XCTest
import Vapor

final class BCryptTests: XCTestCase {
    public func testVersion() throws {
        let digest = try Bcrypt.hash("foo", salt: .generate(cost: 6))
        XCTAssert(digest.string.hasPrefix("$2b$06$"))
    }

    public func testFail() throws {
        let digest = try Bcrypt.hash("foo", salt: .generate(cost: 6))
        let res = try Bcrypt.verify("bar", created: digest)
        XCTAssertEqual(res, false)
    }

    public func testInvalidMinCost() throws {
        XCTAssertThrowsError(try Bcrypt.hash("foo", salt: .generate(cost: 2)))
    }

    public func testInvalidMaxCost() throws {
        XCTAssertThrowsError(try Bcrypt.hash("foo", salt: .generate(cost: 32)))
    }

    public func testInvalidSalt() throws {
        do {
            _ = try Bcrypt.verify("", created: .init(string: "foo"))
            XCTFail("Should have failed")
        } catch let error as Bcrypt.Error {
            print(error)
        }
    }

    public func testVerify() throws {
        for (desired, message) in tests {
            let result = try Bcrypt.verify(message, created: .init(string: desired))
            XCTAssert(result, "\(message): did not match \(desired)")
        }
    }

    public func testNotVerify() throws {
        let result = try Bcrypt.verify(
            "x",
            created: .init(salt: .generate(cost: 12), bytes: [])
        )
        XCTAssertFalse(result, "should not have verified")
    }

    public func testExample1() throws {
        let test = "$2y$12$Iv4bbqusw4TFlXOmEb.06u8hTB8skqwvJiNppo6Qei5FpT/fMx7mq"
        print("REAL: \(test)")
        let digest = try Bcrypt.Digest(string: "$2y$12$Iv4bbqusw4TFlXOmEb.06u8hTB8skqwvJiNppo6Qei5FpT/fMx7mq")
        print("PARS: \(digest.string)")
        XCTAssertEqual(test, digest.string)

        try XCTAssert(Bcrypt.verify("vapor", created: digest))
        let hash = try Bcrypt.hash("vapor", salt: .generate(cost: 4))
        try XCTAssertEqual(Bcrypt.verify("vapor", created: hash), true)
//        try XCTAssertEqual(Bcrypt.verify("foo", created: hash), false)
    }

    func testBase64() {
        XCTAssertEqual(Base64.bcrypt.encode([77, 97, 110]), "TWFu")
        XCTAssertEqual(Base64.bcrypt.encode([77, 97]), "TWE")
        XCTAssertEqual(Base64.bcrypt.encode([77]), "TQ")
        XCTAssertEqual(Base64.bcrypt.encode([0x01, 0x23, 0x45, 0x67, 0x89]), "ASNFZ4k")
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
