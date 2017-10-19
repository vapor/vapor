import XCTest
@testable import JWT

class JWSTests: XCTestCase {
    func testSuccess(for header: Header) throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        
        let signer = Signer<AuthenticationMessage>(secret: secret, identifier: "xctest")
        
        let signature = try JSONWebSignature(header: .hs256(), payload: AuthenticationMessage(token: "test"), signer: signer).sign()
        
        let signedString = try JSONWebSignature(header: .hs256(), payload: AuthenticationMessage(token: "test"), signer: signer).signedString()
        
        XCTAssertEqual(Data(signedString.utf8), signature)
        
        var decoded = try JSONWebSignature<AuthenticationMessage>(from: signature, verifyingAs: signer)
        XCTAssertEqual(decoded.payload.token, "test")
        
        decoded = try JSONWebSignature<AuthenticationMessage>(from: signedString, verifyingAs: signer)
        XCTAssertEqual(decoded.payload.token, "test")
    }
    
    func invalidSignature(for header: Header) throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        let signer = Signer<AuthenticationMessage>(secret: secret, identifier: "xctest")
        
        let otherSecret = Data("dasdasdassad".utf8)
        let otherSigner = Signer<AuthenticationMessage>(secret: otherSecret, identifier: "xctest")
        
        let signature = try JSONWebSignature(header: header, payload: AuthenticationMessage(token: "test"), signer: signer).sign()
        
        XCTAssertThrowsError(try JSONWebSignature<AuthenticationMessage>(from: signature, verifyingAs: otherSigner))
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
    
    func testTimeClaims() throws {
        let secret = Data("aaaaaaaabvbcas".utf8)
        let signer = Signer<TimeClaim>(secret: secret, identifier: "xctest")
        
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
            let jwt = JSONWebSignature(header: .hs256(), payload: claim, signer: signer)
            let token = try jwt.sign()
            
            if expectingFailure {
                XCTAssertThrowsError(try JSONWebSignature(from: token, verifyingAs: signer))
            } else {
                XCTAssertNoThrow(try JSONWebSignature(from: token, verifyingAs: signer))
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
        
        let signer = Signer<AudienceBasedClaim>(secret: secret, identifier: "signer")
        let verifier = Signer<AudienceBasedClaim>(secret: secret, identifier: "verifier")
        
        let validClaim = AudienceBasedClaim(aud: "verifier")
        let invalidClaim = AudienceBasedClaim(aud: "fake")
        
        let validJWT = JSONWebSignature(header: .hs256(), payload: validClaim, signer: signer)
        let validToken = try validJWT.sign()
        
        let invalidJWT = JSONWebSignature(header: .hs256(), payload: invalidClaim, signer: signer)
        let invalidToken = try invalidJWT.sign()
        
        XCTAssertThrowsError(try JSONWebSignature(from: invalidToken, verifyingAs: verifier))
        XCTAssertNoThrow(try JSONWebSignature(from: validToken, verifyingAs: verifier))
    }
    
    static var allTests: [(String, (JWSTests) -> () throws -> Void)] = [
        ("testBasics", testBasics),
        ("testTimeClaims", testTimeClaims),
        ("testAudienceClaim", testAudienceClaim),
    ]
}

struct TimeClaim: JWT, ExpirationClaim, NotBeforeClaim, IssuedAtClaim {
    var exp: Date
    var nbf: Date
    var iat = Date()
    
    init(exp: Date, nbf: Date) {
        self.exp = exp
        self.nbf = nbf
    }
}

struct AudienceBasedClaim: JWT, AudienceClaim {
    var aud: String
    
    init(aud: String) {
        self.aud = aud
    }
}

struct AuthenticationMessage: JWT {
    var token: String
}
