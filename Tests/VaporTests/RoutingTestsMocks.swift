import Foundation
import Vapor
import XCTest

class MockRouter: Router {
    let routes: [Route<Responder>]
    
    private let registerMock: ((Route<Responder>) -> ())?
    private let routeMock: ((Request) -> Responder?)?
    
    func register(route: Route<Responder>) {
        registerMock?(route)
    }
    
    func route(request: Request) -> Responder? {
        if let route = routeMock {
            return route(request)
        }
        return nil
    }
    
    init(registerMock: ((Route<Responder>) -> ())? = nil,
         routeMock: ((Request) -> Responder?)? = nil,
         routes: [Route<Responder>] = []) {
        
        self.registerMock = registerMock
        self.routeMock = routeMock
        self.routes = routes
    }
}

class FakeMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        return try next.respond(to: request)
    }
}

/// Equatable
// FIXME: move to Engine

extension PathComponent.Parameter : Equatable {
    public static func ==(lhs: PathComponent.Parameter, rhs: PathComponent.Parameter) -> Bool {
        return rhs.bytes == lhs.bytes
    }
}

extension PathComponent: Equatable {
    public static func ==(lhs: PathComponent, rhs: PathComponent) -> Bool {
        switch (lhs, rhs) {
        case (.constants(let lParams), .constants(let rParams)):
            return lParams == rParams
        case (.parameter(let lParam), .parameter(let rParam)):
            return lParam == rParam
        default:
            return false
        }
    }
    
    public static func ==(lhs: PathComponent, rhs: String) -> Bool {
        switch lhs {
        case .parameter(let lParam):
            return lParam.string == rhs
        case .constants(let lParams):
            return lParams.first?.string == rhs
        case .anything :
            return false
        }
    }
    
    public static func ==(lhs: String, rhs: PathComponent) -> Bool {
        switch rhs {
        case .parameter(let rParam):
            return rParam.string == lhs
        default:
            return false
        }
    }
    
}


