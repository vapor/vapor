import Foundation
import XCTest
@testable import Vapor

class CipherTests: XCTestCase {
    static let allTests = [
        ("testCipher", testCipher)
    ]

    func testCipher() throws {
        let key = "passwordpasswordpasswordpassword".makeBytes()
        let cipher1 = try CryptoCipher(
            method: .aes256(.cbc), 
            key: key,
            iv: nil,
            encoding: .base64
        )

        
        
        let secret = "vapor"

        let e = try cipher1.encrypt(secret).makeString()
        XCTAssertEqual(e, "jrYw6IVVtC7tA5shwPqc4Q==")
        XCTAssertEqual(try cipher1.decrypt(e).makeString(), secret)

        let cipher2 = try CryptoCipher(
            method: .aes256(.cbc),
            key: key,
            iv: nil,
            encoding: .hex
        )

        let eh = try cipher2.encrypt(secret).makeString()
        XCTAssertEqual(eh, "8eb630e88555b42eed039b21c0fa9ce1")
        XCTAssertEqual(try cipher2.decrypt(eh).makeString(), secret)
    }

    func testDroplet() throws {        
        let config = Config([
            "crypto": [
                "cipher": [
                    "key": "ufEQmM8rsGYM3Nuol4xZuQ==",
                    "method": "aes128",
                    "encoding": "base64"
                ]
            ],
            "droplet": [
                "cipher": "crypto"
            ]
        ])

        let drop = try Droplet(config)

        let secret = "vapor"
        let e = try drop.cipher.encrypt(secret).makeString()
        XCTAssertEqual(e, "cxVfJ0NqJpDHdtSYaYrSmw==")
        XCTAssertEqual(try drop.cipher.decrypt(e).makeString(), secret)
    }
    
}
