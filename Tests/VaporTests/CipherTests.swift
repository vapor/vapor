import Foundation
import XCTest
@testable import Vapor

class CipherTests: XCTestCase {
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
        var config = Config()
        try config.set("crypto", "cipher", to: [
            "key": "ufEQmM8rsGYM3Nuol4xZuQ==",
            "method": "aes128",
            "encoding": "base64"
        ])
        try config.set("droplet", "cipher", to: "crypto")
        let drop = try! Droplet(config)

        let secret = "vapor"
        let cipher = try! drop.cipher()
        
        let e = try! cipher.encrypt(secret).makeString()
        XCTAssertEqual(e, "cxVfJ0NqJpDHdtSYaYrSmw==")
        try! XCTAssertEqual(cipher.decrypt(e).makeString(), secret)
    }
    
    static let allTests = [
        ("testCipher", testCipher),
        ("testDroplet", testDroplet)
    ]
}
