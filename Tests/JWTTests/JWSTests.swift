import XCTest
@testable import JWT

class JWSTests: XCTestCase {
    func testSuccess(for header: Header) throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        
        let signature = try JSONWebSignature(headers: [.hs256()], payload: AuthenticationMessage(token: "test"), secret: secret).sign()
        
        let signedString = try JSONWebSignature(headers: [.hs256()], payload: AuthenticationMessage(token: "test"), secret: secret).signedString()
        
        XCTAssertEqual(Data(signedString.utf8), signature)
        
        var decoded = try JSONWebSignature<AuthenticationMessage>(from: signature, verifyingWith: secret)
        XCTAssertEqual(decoded.payload.token, "test")
        
        decoded = try JSONWebSignature<AuthenticationMessage>(from: signedString, verifyingWith: secret)
        XCTAssertEqual(decoded.payload.token, "test")
    }
    
    func invalidSignature(for header: Header) throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        
        let signature = try JSONWebSignature(headers: [header], payload: AuthenticationMessage(token: "test"), secret: secret).sign()
        
        XCTAssertThrowsError(try JSONWebSignature<AuthenticationMessage>(from: signature, verifyingWith: Data("dsadasdsad".utf8)))
    }
    
    func testBasics() throws {
        let headers: [Header] = [
            .hs256(),
            .hs384(),
            .hs512()
        ]
        
        for header in headers {
            try testSuccess(for: header)
            try invalidSignature(for: header)
        }
    }
    
    static var allTests: [(String, (JWSTests) -> () throws -> Void)] = [
        ("testBasics", testBasics)
    ]
}

struct AuthenticationMessage : Codable {
    var token: String
}
