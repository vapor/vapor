import HTTP
import Foundation
import Vapor
import Routing
import XCTest

class ControllerTests: XCTestCase {
    func testRouting() throws {
        let app = Application()
        let sync = try app.make(SyncRouter.self)
        
        let controller = SyncController(for: app)
        
        controller.on(.get, input: Login.Input.self, to: "user", "joannis") { loginRequest in
            return Login.Output(token: loginRequest.body.username + loginRequest.body.password)
        }
        
        controller.register(to: sync)
        
        let input = Login.Input(username: "example", password: "test")
        let request = try TypeSafeRequest(uri: URI(path: "/user/joannis/"), body: input).makeRequest(using: JSONEncoder())
        
        guard let responder = sync.route(request: request) else {
            XCTFail()
            return
        }
        
        let response = try responder.respond(to: request).sync()
        let output = try JSONDecoder().decode(Login.Output.self, from: response.body)
        
        XCTAssertEqual("exampletest", output.token)
    }
}

enum Login {
    struct Input: Codable {
        var username: String
        var password: String
    }
    
    struct Output: Codable {
        var token: String
    }
}
