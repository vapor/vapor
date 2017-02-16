import Foundation
import XCTest
@testable import Vapor

class CipherTests: XCTestCase {
    static let allTests = [
        ("testCipher", testCipher)
    ]

    func testCipher() throws {
        let key = "passwordpasswordpasswordpassword".makeBytes()
        let cipher = CryptoCipher(method: .chacha20, defaultKey: key, defaultIV: "password".makeBytes())

        let secret = "vapor"

        let e = try cipher.encrypt(secret)
        XCTAssertEqual(e, "huImqu0=")
        XCTAssertEqual(try cipher.decrypt(e), secret)


        let eh = try cipher.encrypt(secret, encoding: .hex)
        XCTAssertEqual(eh, "86e226aaed")
        XCTAssertEqual(try cipher.decrypt(eh, encoding: .hex), secret)
    }

    func testDroplet() throws {
        let config = Config([
            "crypto": [
                "cipher": [
                    "key": "passwordpassword",
                    "method": "aes128"
                ]
            ]
        ])

        let drop = Droplet(config: config)

        let secret = "vapor"
        let e = try drop.cipher.encrypt(secret)
        XCTAssertEqual(e, "b7cMwL66ysKz7+vmKxoJLg==")
        XCTAssertEqual(try drop.cipher.decrypt(e), secret)
    }
    
}
