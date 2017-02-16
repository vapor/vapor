import XCTest
import Core
@testable import Vapor
import HTTP
import Sessions

class ViewTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testViewBytes", testViewBytes),
        ("testViewResponse", testViewResponse),
        ("testViewRequest", testViewRequest)
    ]

    func testBasic() throws {
        let r = TestRenderer(viewsDir: "ferret")
        r.views["foo"] = "42".makeBytes()

        let view = try r.make("foo")
        XCTAssertEqual(view.data.string, "42")


        let view2 = try r.make("foo", "context")
        XCTAssertEqual(view2.data.string, "42")
    }

    func testViewBytes() throws {
        let view = try View(bytes: "42".makeBytes())
        XCTAssertEqual(try view.makeBytes(), "42".makeBytes())
    }


    func testViewResponse() throws {
        let view = try View(bytes: "42 🚀".makeBytes())
        let response = view.makeResponse()

        XCTAssertEqual(response.headers["content-type"], "text/html; charset=utf-8")
        XCTAssertEqual(try response.bodyString(), "42 🚀")
    }
    
    func testViewRequest() throws {
        let drop = Droplet()
        
        let request = Request(method: .get, path: "/foopath")
        
        let memory = MemorySessions()
        let sessions = SessionsMiddleware(sessions: memory)
        drop.middleware.append(sessions)
        
        // sets up a session on the request
        let _ = try drop.respond(to: request)
        
        request.storage["test"] = "foobar"
        try request.session().data["name"] = "Vapor"
        
        final class TestRenderer: ViewRenderer {
            init(viewsDir: String) { }
            
            func make(_ path: String, _ context: Node) throws -> View {
                return View(data: "\(context)".makeBytes())
            }
        }
        
        drop.view = TestRenderer(viewsDir: "")
        
        let view = try drop.view.make("test-template", for: request)
        let string = try view.data.string()
        
        XCTAssert(string.contains("Vapor"))
        XCTAssert(string.contains("foopath"))
        XCTAssert(string.contains("foobar"))
    }
}
