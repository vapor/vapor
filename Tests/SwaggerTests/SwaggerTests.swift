import XCTest
import HTTP
import Swagger
import Routing

extension TrieRouter: SyncRouter {}

class SwaggerTests: XCTestCase {
    func testBasics() throws {
        let router = TrieRouter()
        
        router.on(.get, to: "hello", "world") { _ in
            return try Response(body: "Hello world")
        }.describe(as: """
            Prints "Hello world" using a `200` OK status code
        """) { _ in
            return Swagger.Operation(response: "Hello world")
        }
        
        try router.describeAPI(named: "example").write(to: URL(fileURLWithPath: "/Users/joannisorlandos/test.json"))
    }
    
    static var allTests = [
        ("testBasics", testBasics),
    ]
}
