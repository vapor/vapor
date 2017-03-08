import Foundation
import XCTest
@testable import Vapor

class CipherTests: XCTestCase {
    static let allTests = [
        ("testCipher", testCipher)
    ]

    func testCipher() throws {
        let key = "passwordpasswordpasswordpassword".makeBytes()
        let cipher = CryptoCipher(
            method: .aes256(.cbc), 
            defaultKey: key, 
            defaultIV: nil
        )

        let secret = "vapor"

        let e = try cipher.encrypt(secret)
        XCTAssertEqual(e, "jrYw6IVVtC7tA5shwPqc4Q==")
        XCTAssertEqual(try cipher.decrypt(e), secret)


        let eh = try cipher.encrypt(secret, encoding: .hex)
        XCTAssertEqual(eh, "8eb630e88555b42eed039b21c0fa9ce1")
        XCTAssertEqual(try cipher.decrypt(eh, encoding: .hex), secret)
    }

    func testDroplet() throws {
        let config = Config([
            "crypto": [
                "cipher": [
                    "key": "passwordpassword",
                    "method": "aes128"
                ]
            ],
            "droplet": [
                "cipher": "crypto"
            ]
        ])

        let drop = try Droplet(config: config)

        let secret = "vapor"
        let e = try drop.cipher.encrypt(secret)
        XCTAssertEqual(e, "b7cMwL66ysKz7+vmKxoJLg==")
        XCTAssertEqual(try drop.cipher.decrypt(e), secret)
    }
    
}
