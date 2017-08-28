import XCTest
import Crypto

class PBKDF2Tests: XCTestCase {
    static var allTests = [
        ("testSHA1", testSHA1),
        ("testMD5", testMD5),
        ("testPerformance", testPerformance),
    ]

    func testSHA1() throws {
        // Source: PHP/produce_tests.php
        let tests: [(key: String, salt: String, expected: String, iterations: Int)] = [
            ("password", "longsalt", "1712d0a135d5fcd98f00bb25407035c41f01086a", 1000),
            ("password2", "othersalt", "7a0363dd39e51c2cf86218038ad55f6fbbff6291", 1000),
            ("somewhatlongpasswordstringthatIwanttotest", "1", "8cba8dd99a165833c8d7e3530641c0ecddc6e48c", 1000),
            ("p", "somewhatlongsaltstringthatIwanttotest", "31593b82b859877ea36dc474503d073e6d56a33d", 1000),
        ]
        
        for test in tests {
            let result = try PBKDF2<SHA1>.derive(fromPassword: Data(test.key.utf8), saltedWith: Data(test.salt.utf8), iterating: test.iterations, derivedKeyLength: SHA1.digestSize).hexString.lowercased()
            
            XCTAssertEqual(result, test.expected.lowercased())
        }
    }

    func testMD5() throws {
        // Source: PHP/produce_tests.php
        let tests: [(key: String, salt: String, expected: String, iterations: Int)] = [
            ("password", "longsalt", "95d6567274c3ed283041d5135c798823", 1000),
            ("password2", "othersalt", "78e4d28875d6f3b92a01dbddc07370f1", 1000),
            ("somewhatlongpasswordstringthatIwanttotest", "1", "c91a23ffd2a352f0f49c6ce64146fc0a", 1000),
            ("p", "somewhatlongsaltstringthatIwanttotest", "4d0297fc7c9afd51038a0235926582bc", 1000),
        ]
        
        for test in tests {
            let result = try PBKDF2<MD5>.derive(fromPassword: Data(test.key.utf8), saltedWith: Data(test.salt.utf8), iterating: test.iterations, derivedKeyLength: MD5.digestSize).hexString.lowercased()
            
            XCTAssertEqual(result, test.expected.lowercased())
        }
    }
    
    func testPerformance() {
        // ~0.137 release
        measure {
            _ = try! PBKDF2<SHA1>.derive(fromPassword: Data("p".utf8), saltedWith: Data("somewhatlongsaltstringthatIwanttotest".utf8), iterating: 10_000, derivedKeyLength: SHA1.digestSize)
        }
    }
}

