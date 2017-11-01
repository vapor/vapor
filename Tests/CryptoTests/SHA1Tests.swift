import XCTest
import Crypto

class SHA1Tests: XCTestCase {
    static var allTests = [
        ("testBasic", testBasic),
//        ("testPerformance", testPerformance),
        ("testHMAC", testHMAC),
    ]

    func testBasic() throws {
        // Source: https://en.wikipedia.org/wiki/SHA-1#Example_hashes
        let tests: [(key: String, expected: String)] = [
            (
                "The quick brown fox jumps over the lazy dog",
                "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"
            ),
            (
                "The quick brown fox jumps over the lazy cog",
                "de9f2c7fd25e1b3afad3e85a0bd17d9b100db4b3"
            ),
            (
                "",
                "da39a3ee5e6b4b0d3255bfef95601890afd80709"
            ),
            (
                "abc",
                "A9993E364706816ABA3E25717850C26C9CD0D89D"
            ),
            (
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                "84983E441C3BD26EBAAE4AA1F95129E5E54670F1"
            ),
            (
                "a",
                "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8"
            ),
            (
                "0123456701234567012345670123456701234567012345670123456701234567",
                "e0c094e867ef46c350ef54a7f59dd60bed92ae83"
            )
        ]
        
        for test in tests {
            let result = SHA1.hash(Data(test.key.utf8)).hexString.lowercased()
            XCTAssertEqual(result, test.expected.lowercased())
        }
    }
    
    func testNotCrashing() {
        let data = Data(repeating: 0x02, count: 263)
        
        _ = SHA1.hash(data)
    }

    func testHMAC() throws {
        let tests: [(key: String, message: String, expected: String)] = [
            (
                "vapor",
                "hello",
                "bb2a9aabb537902647f3f40bfecb679bf0d7d64b"
            ),
            (
                "true",
                "2+2=4",
                "35836a9520eb061ad7e267ac37ab3ee1fafa6e4b"
            )
        ]

        for test in tests {
            let result = HMAC<SHA1>.authenticate(
                Data(test.message.utf8),
                withKey: Data(test.key.utf8)
                ).hexString.lowercased()
            XCTAssertEqual(result, test.expected.lowercased())
        }

        // Source: https://github.com/krzyzanowskim/CryptoSwift/blob/swift3-snapshots/CryptoSwiftTests/HMACTests.swift
        XCTAssertEqual(
            HMAC<SHA1>.authenticate(Data(), withKey: Data()),
            Data([0xfb,0xdb,0x1d,0x1b,0x18,0xaa,0x6c,0x08,0x32,0x4b,0x7d,0x64,0xb7,0x1f,0xb7,0x63,0x70,0x69,0x0e,0x1d])
        )
    }
}

