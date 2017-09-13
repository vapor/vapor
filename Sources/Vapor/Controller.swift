import Core
import Foundation
import HTTP
import Service
import Routing

public protocol ContentEncoder {
    func encodeBody<E: Encodable>(from entity: E) throws -> Body
}

public protocol ContentDecoder {
    func decode<D: Decodable>(_ entity: D.Type, from body: Body) throws -> D
}

extension JSONEncoder: ContentEncoder {
    public func encodeBody<E>(from entity: E) throws -> Body where E : Encodable {
        return Body(try self.encode(entity))
    }
}

extension JSONDecoder: ContentDecoder {
    public func decode<D>(_ entity: D.Type, from body: Body) throws -> D where D : Decodable {
        return try self.decode(D.self, from: body.data)
    }
}

open class AsyncController<C: Container> {
    public let container: C
    public var routes = [Route]()
    
    public init(for container: C) {
        self.container = container
    }
    
    public func register(to router: Router) {
        for route in routes {
            router.register(route: route)
        }
    }
    
    @discardableResult
    public func on<Input, Output>(_ method: HTTP.Method, input: Input.Type, to path: PathComponentRepresentable..., use closure: @escaping (TypeSafeRequest<Input>) throws -> Future<TypeSafeResponse<Output>>) -> Route {
        let responder = BasicAsyncResponder { (request: Request) -> Future<Response> in
            let typeSafeRequest = try TypeSafeRequest<Input>(request: request, for: self.container)
            
            return try closure(typeSafeRequest).map { response in
                return try response.makeResponse(for: request, for: self.container)
            }
        }
        
        let route = Route(method: method, path: path.makePathComponents(), responder: responder)
        routes.append(route)
        return route
    }
}

open class SyncController<C: Container> {
    public let container: C
    public var routes = [Route]()
    
    public init(for container: C) {
        self.container = container
    }
    
    public func register(to router: Router) {
        for route in routes {
            router.register(route: route)
        }
    }
}

extension SyncController {
    
    @discardableResult
    public func on<Input, Output>(_ method: HTTP.Method, input: Input.Type, to path: PathComponentRepresentable..., use closure: @escaping (TypeSafeRequest<Input>) throws -> TypeSafeResponse<Output>) -> Route {
        let responder = BasicSyncResponder { (request: Request) -> Response in
            let typeSafeRequest = try TypeSafeRequest<Input>(request: request, for: self.container)
            
            return try closure(typeSafeRequest).makeResponse(for: request, for: self.container)
        }
        
        let route = Route(method: method, path: path.makePathComponents(), responder: responder)
        routes.append(route)
        return route
    }
    
    @discardableResult
    public func on<Input, Output: Codable>(_ method: HTTP.Method, input: Input.Type, to path: PathComponentRepresentable..., use closure: @escaping (TypeSafeRequest<Input>) throws -> Output) -> Route {
        let responder = BasicSyncResponder { (request: Request) -> Response in
            let typeSafeRequest = try TypeSafeRequest<Input>(request: request, for: self.container)
            
            let output = try closure(typeSafeRequest)
            let response = TypeSafeResponse(body: output)
            
            return try response.makeResponse(for: request, for: self.container)
        }
        
        let route = Route(method: method, path: path.makePathComponents(), responder: responder)
        routes.append(route)
        return route
    }
}
