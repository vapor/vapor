// FIXME: Remove Commented out code

@testable import Vapor
@testable import Auth
@testable import HTTP
@testable import Fluent
import XCTest

class AuthTests: XCTestCase {
    static let allTests = [
        ("testUserLogin", testUserLogin),
        ("testProtectedRoute", testProtectedRoute),
        ("testUserLogout", testUserLogout)
    ]
    
    var database:Database!
    var droplet:Droplet!
    
    
    override func setUp() {
        
        //setup droplet
        database = Database(MemoryDriver())
        droplet = Droplet()
        
        droplet.database = database
        
//        let authMiddleware = AuthMiddleware(user: Userz.self)
//        droplet.middleware.append(authMiddleware)

    }
    
    /**
        Logs in a basic user with provided credentials.
        Can be used in any tests requiring auth.
        Will provide a response with an auth cookie only
        with an Identifier with an id of 1.
    */
//    func login(credentials:Identifier) throws -> Response {
//
//        //First : creates a dummy user with an Id of 1 if not exists
//        Userz.database = self.database
//        if try Userz.find(1) == nil {
//            var user = Userz(name: "John")
//            try user.save()
//        }
//        
//        //Second : Bind the login request to a registered "login" route
//        let login = Request(method: .get, path: "login")
//        droplet.get("login") { req in
//            
//            try req.auth.login(credentials) // id of first item inserted
//            return try req.auth.user().converted(to: JSON.self)
//        }
//        
//        //Third : If successful, returns a response containing the user logged in as JSON and vapor-auth cookie
//        return try droplet.respond(to: login)
//    }

    func testUserLogin() throws {
        
//        let authenticated = try login(credentials: Identifier(id: 1))
//        XCTAssertEqual(authenticated.status, .ok)
//        XCTAssertEqual(authenticated.data["name"]?.string, "John")
//        
//        let cookie = authenticated.cookies.cookies.first!
//        XCTAssertEqual(cookie.name, "vapor-auth")
//        XCTAssertNotNil(cookie.value)
//        XCTAssertNotNil(cookie.expires)
//        XCTAssertFalse(cookie.secure)
//        // FIXME: SHould this be true? We're initializing w/ true -- double check w/ Tanner and David Keegan who's tagged in commits on these lines
//        XCTAssertTrue(cookie.httpOnly)
//        
//        
//        let notAuthenticated = try login(credentials: Identifier(id: 2)) // user with id of 2 does not exist in the database
//        XCTAssertNotEqual(notAuthenticated.status, .ok)
//        XCTAssertNil(notAuthenticated.cookies["vapor-auth"])
        
    }
    
    func testProtectedRoute() throws {
        
//        let protectMiddleware = ProtectMiddleware(error: Abort.custom(status: .methodNotAllowed, message: ""))
//        
//        droplet.group(protectMiddleware) { secure in
//            secure.get("secure") { req in
//                return try req.auth.user().converted(to: JSON.self)
//            }
//        }
//        
//        let secure = Request(method: .get, path:"secure")
//
//        var protected = try droplet.respond(to: secure)
//        XCTAssertEqual(protected.status, .methodNotAllowed) // thrown from ProtectMiddleware
//        
//        let authenticated = try login(credentials:Identifier(id: 1))
//        secure.cookies = authenticated.cookies //set appropriate login cookie
//        
//        protected = try droplet.respond(to: secure)
//        XCTAssertEqual(protected.status, .ok)
//        XCTAssertEqual(protected.data["name"]?.string, "John")

    }
    
    func testUserLogout() throws {
        
//        droplet.get("logout") { req in
//            
//            let user = try req.auth.user() as? User
//            XCTAssertNotNil(user)
//            XCTAssertEqual(user?.id, 1)
//            try req.auth.logout()
//            
//            return JSON(["message": "User logged out"])
//        }
//        
//        let request = Request(method: .get, path: "logout")
//        
//        let authenticated = try login(credentials: Identifier(id: 1))
//        request.cookies = authenticated.cookies //set appropriate login cookie
//        
//        let res = try droplet.respond(to: request)
//        XCTAssertEqual(res.status, .ok)
//        XCTAssertNil(res.cookies["vapor-auth"])
//        XCTAssertEqual(res.data["message"]?.string, "User logged out")
    }

}

/**
    Utilities/User.swift conforms to Auth.User
    in order to log it in & out.
 */

//extension User: Auth.User {
//    
//    public static func register(credentials: Credentials) throws -> Auth.User {
//        //required but not used
//        return User(name: "Dummy user")
//    }
//    
//    public static func authenticate(credentials: Credentials) throws -> Auth.User {
//        
//        let identifier = credentials as? Identifier
//        XCTAssertNotNil(identifier)
//        
//        guard let id = identifier?.id, let user = try User.find(id) else {
//            throw Abort.custom(status: .methodNotAllowed, message: "")
//        }
//        
//        return user
//    }
//
//}

