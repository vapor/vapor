import HTTP
import Foundation
import Vapor
import Routing
import XCTest

class ControllerTests: XCTestCase {
    func testRouting() throws {
        let app = Application()
        let sync = try app.make(SyncRouter.self)
        
        sync.get("user", "example") { req in
            let loginRequest = try req.decode(as: Login.Input.self)
            
            return Login.Output(token: loginRequest.username + loginRequest.password)
        }
        
        let input = Login.Input(username: "example", password: "test")
        let body = try JSONEncoder.encodeBody(from: input)
        
        let request = Request(uri: URI(path: "/user/example/"), body: body)
        request.mediaType = .json
        request.headers[.accept] = MediaType.json.description
        
        guard let responder = sync.route(request: request) else {
            XCTFail()
            return
        }
        
        let response = try responder.respond(to: request).sync()
        let output = try JSONDecoder.decodeBody(response.body, as: Login.Output.self)
        
        XCTAssertEqual("exampletest", output.token)
    }
}

enum Login {
    struct Input: Codable {
        var username: String
        var password: String
    }
    
    struct Output: Codable, ResponseRepresentable {
        var token: String
    }
}
