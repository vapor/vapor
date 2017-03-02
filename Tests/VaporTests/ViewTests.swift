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
        
        let session = Session(identifier: "abc")
        request.storage["session"] = session
        
        request.storage["test"] = "foobar"
        
        session.data = Node.object([
            "name": "Vapor"
        ])
        
        final class TestRenderer: ViewRenderer {
            init(viewsDir: String) {
                
            }
            
            func make(_ path: String, _ context: Node) throws -> View {
                return View(data: "\(context)".bytes)
              
            }
        }

        drop.view = TestRenderer(viewsDir: "")
        
        let view = try drop.view.make("test-template", for: request)
        let string = try view.data.string()
        
        XCTAssert(string.contains("Vapor"))
        XCTAssert(string.contains("foopath"))
        XCTAssert(string.contains("foobar"))
    }

    func testLeafRenderer() throws {
        var directory = #file.components(separatedBy: "/")
        let file = directory.removeLast()
        let renderer = LeafRenderer(viewsDir: directory.joined(separator: "/"))
        let result = try renderer.make(file, [])
        XCTAssert(result.data.string.contains("meta string"))
    }
}
