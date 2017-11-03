import XCTest
@testable import JWT

class JWSTests: XCTestCase {
    func testSuccess(for header: JWTHeader) throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        
        let signer = JWTSigner(secret: secret, identifier: "xctest")
        
        let token = AuthenticationMessage(token: "test")
        let signature = try signer.signPayload(token, using: .hs256())
        let signedString = String(data: signature, encoding: .utf8) ?? ""
        
        var decoded = try AuthenticationMessage(from: signature, verifiedWith: signer)
        XCTAssertEqual(decoded.token, "test")
        
        decoded = try AuthenticationMessage(from: signedString, verifiedWith: signer)
        XCTAssertEqual(decoded.token, "test")
    }
    
    func invalidSignature(for header: JWTHeader) throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        let signer = JWTSigner(secret: secret, identifier: "xctest")
        
        let otherSecret = Data("dasdasdassad".utf8)
        let otherSigner = JWTSigner(secret: otherSecret, identifier: "xctest")
        
        let token = AuthenticationMessage(token: "test")
        let signature = try signer.signPayload(token, using: header)
        
        XCTAssertThrowsError(try AuthenticationMessage(from: signature, verifiedWith: otherSigner))
    }
    
    func testBasics() throws {
        let headers: [JWTHeader] = [
            .hs256(),
            .hs384(),
            .hs512()
        ]
        
        for header in headers {
            try testSuccess(for: header)
            try invalidSignature(for: header)
        }
    }
    
    func testTimeClaims() throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        let signer = JWTSigner(secret: secret, identifier: "xctest")
        
        let alreadyExpired = TimeClaim(
            exp: Date().addingTimeInterval(-5),
            nbf: Date().addingTimeInterval(-10)
        )
        
        let brokenAlreadyExpired = TimeClaim(
            exp: Date().addingTimeInterval(-5),
            nbf: Date()
        )
        
        let brokenJustExpired = TimeClaim(exp: Date(), nbf: Date())
        let justExpired = TimeClaim(exp: Date(), nbf: Date().addingTimeInterval(-1))
        
        let brokenNotExpired = TimeClaim(
            exp: Date(),
            nbf: Date()
        )
        
        let notExpired = TimeClaim(
            exp: Date().addingTimeInterval(5),
            nbf: Date()
        )
        
        func test(claim: TimeClaim, expectingFailure: Bool) throws {
            let token = try signer.signPayload(claim, using: .hs256())
            
            if expectingFailure {
                XCTAssertThrowsError(try TimeClaim(from: token, verifiedWith: signer))
            } else {
                XCTAssertNoThrow(try TimeClaim(from: token, verifiedWith: signer))
            }
        }
        
        try test(claim: alreadyExpired, expectingFailure: true)
        try test(claim: brokenAlreadyExpired, expectingFailure: true)
        try test(claim: brokenJustExpired, expectingFailure: true)
        try test(claim: justExpired, expectingFailure: true)
        try test(claim: brokenNotExpired, expectingFailure: true)
        try test(claim: notExpired, expectingFailure: false)
    }
    
    func testAudienceClaim() throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        
        let signer = JWTSigner(secret: secret, identifier: "signer")
        let verifier = JWTSigner(secret: secret, identifier: "verifier")
        
        let validClaim = AudienceBasedClaim(aud: "verifier")
        let invalidClaim = AudienceBasedClaim(aud: "fake")
        
        let validToken = try signer.signPayload(validClaim, using: .hs256())
        
        let invalidToken = try signer.signPayload(invalidClaim, using: .hs256())
        
        XCTAssertThrowsError(try AudienceBasedClaim(from: invalidToken, verifiedWith: verifier))
        XCTAssertNoThrow(try AudienceBasedClaim(from: validToken, verifiedWith: verifier))
    }
    
    static var allTests: [(String, (JWSTests) -> () throws -> Void)] = [
        ("testBasics", testBasics),
        ("testTimeClaims", testTimeClaims),
        ("testAudienceClaim", testAudienceClaim),
    ]
}

struct TimeClaim: JWTPayload, ExpirationClaim, NotBeforeClaim, IssuedAtClaim {
    func verify() throws {}
    
    var exp: Date
    var nbf: Date
    var iat = Date()
    
    init(exp: Date, nbf: Date) {
        self.exp = exp
        self.nbf = nbf
    }
}

struct AudienceBasedClaim: JWTPayload, AudienceClaim {
    func verify() throws {}
    
    var aud: String
    
    init(aud: String) {
        self.aud = aud
    }
}

struct AuthenticationMessage: JWTPayload {
    func verify() throws {}
    
    var token: String
}
