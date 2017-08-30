import XCTest
import Crypto

class SHA2Tests: XCTestCase {
    static var allTests = [
        ("testSHA224Basic", testSHA224Basic),
        ("testSHA256Basic", testSHA256Basic),
        ("testSHA384Basic", testSHA384Basic),
        ("testSHA512Basic", testSHA512Basic),
        ("testSHA224Performance", testSHA224Performance),
        ("testSHA256Performance", testSHA256Performance),
        ("testSHA384Performance", testSHA384Performance),
        ("testSHA512Performance", testSHA512Performance),
    ]
    
    func testSHA224Basic() throws {
        let tests: [(key: String, expected: String)] = [
            (
                "The quick brown fox jumps over the lazy dog",
                "730e109bd7a8a32b1cb9d9a09aa2325d2430587ddbc0c38bad911525"
            ),
            (
                "The quick brown fox jumps over the lazy cog",
                "fee755f44a55f20fb3362cdc3c493615b3cb574ed95ce610ee5b1e9b"
            ),
            (
                "Pa$SW0|2d",
                "fa25e83c28c8326e1ed7da6215d5620c7fb88259595c07f138eb84ee"
            )
        ]
        
        for test in tests {
            let result = SHA224.hash(Data(test.key.utf8)).hexString.lowercased()
            XCTAssertEqual(result, test.expected.lowercased())
        }
    }
    
    func testSHA256Basic() throws {
        let tests: [(key: String, expected: String)] = [
            (
                "The quick brown fox jumps over the lazy dog",
                "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"
            ),
            (
                "The quick brown fox jumps over the lazy cog",
                "e4c4d8f3bf76b692de791a173e05321150f7a345b46484fe427f6acc7ecc81be"
            ),
            (
                "Pa$SW0|2d",
                "c2bb64cc6937ab83020d6114d411d6d3de14d89ad73560a4036b7267b3121856"
            )
        ]
        
        for test in tests {
            let result = SHA256.hash(Data(test.key.utf8)).hexString.lowercased()
            XCTAssertEqual(result, test.expected.lowercased())
        }
    }
    
    func testSHA384Basic() throws {
        let tests: [(key: String, expected: String)] = [
            (
                "The quick brown fox jumps over the lazy dog",
                "ca737f1014a48f4c0b6dd43cb177b0afd9e5169367544c494011e3317dbf9a509cb1e5dc1e85a941bbee3d7f2afbc9b1"
            ),
            (
                "The quick brown fox jumps over the lazy cog",
                "098cea620b0978caa5f0befba6ddcf22764bea977e1c70b3483edfdf1de25f4b40d6cea3cadf00f809d422feb1f0161b"
            ),
            (
                "Pa$SW0|2d",
                "8625b180d9108f2ce79f4b45462b90e0bf3ac6672333bb4b61b81ed0dd2b7f75d9e0a21a4a9201b6f4366d05cd25d3ec"
            )
        ]

        for test in tests {
            let result = SHA384.hash(Data(test.key.utf8)).hexString.lowercased()
            XCTAssertEqual(result, test.expected.lowercased())
        }
    }

    func testSHA512Basic() throws {
        let tests: [(key: String, expected: String)] = [
            (
                "The quick brown fox jumps over the lazy dog",
                "07e547d9586f6a73f73fbac0435ed76951218fb7d0c8d788a309d785436bbb642e93a252a954f23912547d1e8a3b5ed6e1bfd7097821233fa0538f3db854fee6"
            ),
            (
                "The quick brown fox jumps over the lazy cog",
                "3eeee1d0e11733ef152a6c29503b3ae20c4f1f3cda4cb26f1bc1a41f91c7fe4ab3bd86494049e201c4bd5155f31ecb7a3c8606843c4cc8dfcab7da11c8ae5045"
            ),
            (
                "Pa$SW0|2d",
                "d9d9d269119f146e54677895d44f712b8f1c361df6a085b03a44a00018479239b0835137e2921400c2d9a51f02d009804f563cd4c95d09c494b6e12242a81eff"
            )
        ]

        for test in tests {
            let result = SHA512.hash(Data(test.key.utf8)).hexString.lowercased()
            XCTAssertEqual(result, test.expected.lowercased())
        }
    }

    func testSHA224Performance() throws {
        measure {
            _ = SHA224.hash(Data("kaas".utf8))
        }
    }
    
    func testSHA256Performance() throws {
        measure {
            _ = SHA256.hash(Data("kaas".utf8))
        }
    }
    
    func testSHA384Performance() throws {
        measure {
            _ = SHA384.hash(Data("kaas".utf8))
        }
    }

    func testSHA512Performance() throws {
        measure {
            _ = SHA512.hash(Data("kaas".utf8))
        }
    }
}

