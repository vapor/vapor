import XCTest
@testable import JWT

class JWSTests: XCTestCase {
    func testBasics() throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        
        let signature = try JSONWebSignature(headers: [.hs256()], payload: AuthenticationMessage(token: "test"), secret: secret).sign()
        
        let decoded = try JSONWebSignature<AuthenticationMessage>(from: signature, verifyingWith: secret)
        XCTAssertEqual(decoded.payload.token, "test")
    }
    
    func testInvalidSignature() throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        
        let signature = try JSONWebSignature(headers: [.hs256()], payload: AuthenticationMessage(token: "test"), secret: secret).sign()
        
        XCTAssertThrowsError(try JSONWebSignature<AuthenticationMessage>(from: signature, verifyingWith: Data("dsadasdsad".utf8)))
    }
    
    static var allTests: [(String, (JWSTests) -> () throws -> Void)] = [
        ("testBasics", testBasics),
    ]
}

struct AuthenticationMessage : Codable {
    var token: String
}
