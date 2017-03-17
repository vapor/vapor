import Foundation
import XCTest
@testable import Vapor
import Crypto

class HashTests: XCTestCase {
    static let allTests = [
        ("testHash", testHash),
        ("testDroplet", testDroplet),
        ("testBCrypt", testBCrypt),
        ("testDropletBCrypt", testDropletBCrypt),
    ]

    func testHash() throws {
        let string = "vapor"
        let defaultExpected = "97ce9a45eaf0b1ceafc3bba00dfec047526386bbd69241e4a4f0c9fde7c638ea"
        let key = "123"

        //test Hash by itself
        let hash = CryptoHasher(hmac: .sha256, encoding: .hex, key: key.makeBytes())
        XCTAssertEqual(defaultExpected, try hash.make(string).makeString(), "Hash did not match")

        //test all variants of manually
        var expected: [HMAC.Method: String] = [:]
        expected[.sha256] = "97ce9a45eaf0b1ceafc3bba00dfec047526386bbd69241e4a4f0c9fde7c638ea"
        expected[.sha384] = "3977579292ed6c50588c5e2e345e84470a8e7f2635ecd89cacedb9d747d05bddb767c2c6943f7ed8ae3abf8c8000bd89"
        expected[.sha512] = "9215c98b5ea5826961395de57f8e4cd2baf3d08c429d4db0f4e2d83feb12e989ffbc7dbf8611ed65ef13e6e8d5f370a803065708f38fd73a349f0869b7891bc6"

        for (variant, expect) in expected {
            let hasher = CryptoHasher(hmac: variant, encoding: .hex, key: key.makeBytes())
            let result = try hasher.make(string).makeString()
            XCTAssert(result == expect, "Hash for \(variant) did not match")
        }
    }

    func testDroplet() throws {
        let string = "vapor"
        let defaultExpected = "fb7ae694ba3fd90ae3909ccccd0be0dae988e70296d7099bc5708a872f4cc172"

        //test drop facade
        let config = Config([
            "crypto": [
                "hash": [
                    "method": "sha256",
                    "encoding": "hex"
                ]
            ],
            "droplet": [
                "hash": "crypto"
            ]
        ])
        let drop = try Droplet(config: config)
        let result = try drop.hash.make(string).makeString()
        XCTAssert(defaultExpected == result, "Hash did not match")
    }

    func testBCrypt() throws {
        let workFactor: UInt = 5
        let password = "foo"

        let hash: HashProtocol = BCryptHasher(cost: workFactor)

        let digest1 = try hash.make(password).makeString()
        let digest2 = try hash.make(password).makeString()
        let digest3 = "$2a$05$LCgyKIaj2Mv1uDZZB6DMT.zruhilEevoFkyToS8CIwpSecp/2dg3u" // foo from online

        XCTAssert(digest1.contains("$0\(workFactor)$"))
        XCTAssert(digest1 != digest2)
        XCTAssert(try hash.check(password, matchesHash: digest1))
        XCTAssert(try hash.check(password, matchesHash: digest2))
        XCTAssert(try hash.check(password, matchesHash: digest3))
    }

    func testDropletBCrypt() throws {
        let workFactor: UInt = 7
        let string = "vapor"

        let config = try Config(node: [
            "droplet": [
                "hash": "bcrypt"
            ],
            "bcrypt": [
                "cost": workFactor
            ]
        ])
        let drop = try Droplet(config: config)
        let result = try drop.hash.make(string).makeString()

        let other = BCryptHasher(cost: workFactor)
        XCTAssertTrue(
            try other.check(string, matchesHash: result),
            "Droplet hash did not match BCrypt with workFactor 7"
        )
    }
}
