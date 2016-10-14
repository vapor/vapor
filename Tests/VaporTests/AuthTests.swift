@testable import Vapor
@testable import Auth
@testable import HTTP
@testable import Fluent
import XCTest

class AuthTests: XCTestCase {
    static let allTests = [
        ("testUserLoginAndOut", testUserLoginAndOut),
    ]
    
    var database:Database!
    var droplet:Droplet!
    
    
    override func setUp() {
        
        //setup droplet
        database = Database(MemoryDriver())
        droplet = Droplet()
        
        droplet.database = database
        
        let authMiddleware = AuthMiddleware(user: User.self)
        droplet.middleware.append(authMiddleware)
        
        //creates dummy user
        User.database = database

        do {
            var user = User(name:"John")
            try user.save()
            
        } catch {
            XCTFail("Could not create User")
        }
        
    }
    
    func testUserLoginAndOut() throws {
        let request = Request(method: .get, path: "login")
        
        droplet.get("login") { req in
            
            try req.auth.login(Identifier(id:1)) // id of first item inserted
            return try req.auth.user().converted(to: JSON.self)
        }
        
        let res = try droplet.respond(to: request)
        
        XCTAssertEqual(res.status, .ok)
        XCTAssertEqual(res.data["name"]?.string, "John")
        XCTAssertNotNil(res.cookies["vapor-auth"])
        
        try testUserLogout(with: res) //try to logout with content of response (w/ cookies etc.)
        
    }
    
    func testUserLogout(with response:Response) throws {
        let request = Request(method: .get, path: "logout")
        request.cookies = response.cookies
        
        droplet.get("logout") { req in
            
            guard let user = try req.auth.user() as? User, user.id == 1 else {
                throw User.Error.userNotLoggedIn
            }
            
            try req.auth.logout()
            
            return JSON(["message": "User logged out"])
        }
        
        let res = try droplet.respond(to: request)
        XCTAssertEqual(res.status, .ok)
        XCTAssertNil(res.cookies["vapor-auth"])
        XCTAssertEqual(res.data["message"]?.string, "User logged out")
    }

}

/**
    Utilities/User.swift conforms to Auth.User
    in order to log it in & out.
 */

extension User: Auth.User {
    
    enum Error:Swift.Error {
        case invalidCredentialType
        case userNotFound
        case userNotLoggedIn
        case notAllowed
    }
    
    public static func register(credentials: Credentials) throws -> Auth.User {
        //required but not used
        return User(name: "Dummy user")
    }
    
    public static func authenticate(credentials: Credentials) throws -> Auth.User {
        
        guard let id = credentials as? Identifier else {
            throw Error.invalidCredentialType
        }
        
        let user = try User.find(id.id)
        
        guard let u = user else {
            throw Error.userNotFound
        }
        
        return u
        
    }

}

