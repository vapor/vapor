import XCTest
@testable import JWT

class JWSTests: XCTestCase {
    func testParse() throws {
        let data = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6OTk5OTk5OTk5OTk5fQ.Ks7KcdjrlUTYaSNeAO5SzBla_sFCHkUh4vvJYn6q29U"

        let signer = JWTSigner.hs256(key: Data("secret".utf8))
        let jwt = try JWT<TestPayload>(from: data, verifiedUsing: signer)
        XCTAssertEqual(jwt.payload.name, "John Doe")
        XCTAssertEqual(jwt.payload.sub.value, "1234567890")
        XCTAssertEqual(jwt.payload.admin, true)
    }

    func testExpired() throws {
        let data = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6MX0.-x_DAYIg4R4R9oZssqgWyJP_oWO1ESj8DgKrGCk7i5o"

        let signer = JWTSigner.hs256(key: Data("secret".utf8))
        do {
            _ = try JWT<TestPayload>(from: data, verifiedUsing: signer)
        } catch let error as JWTError {
            XCTAssertEqual(error.identifier, "exp")
        }
    }

    func testSigners() throws {
        let data = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImZvbyJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6OTk5OTk5OTk5OTk5OTl9.Gf7leJ8i30LmMI7GBTpWDMXV60y1wkTOCOBudP9v9ms"

        let signer = JWTSigner.hs256(key: Data("bar".utf8))
        let signers = JWTSigners()
        signers.use(signer, kid: "foo")

        let jwt = try! JWT<TestPayload>(from: data, verifiedUsing: signers)
        XCTAssertEqual(jwt.payload.name, "John Doe")
    }
    
    static var allTests = [
        ("testParse", testParse),
        ("testExpired", testExpired),
        ("testSigners", testSigners),
    ]
}

struct TestPayload: JWTPayload {
    var sub: SubjectClaim
    var name: String
    var admin: Bool
    var exp: ExpirationClaim

    func verify() throws {
        try exp.verify()
    }
}
