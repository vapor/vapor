import Core
import HTTP
import Service
import Routing

public protocol ContentEncoder {
    func encode<E: Encodable>(_ entity: E) throws -> Body
}

public protocol ContentDecoder {
    func decode<D: Decodable>(_ entity: D.Type, from body: Body) throws -> D
}

open class AsyncController<Input: Codable, Output: Codable> {
    /// Responder closure
    public typealias Closure = (TypeSafeRequest<Input>) throws -> Future<TypeSafeResponse<Output>>
    
    let container: Application
    
    var routes = [Route]()
    
    init(for app: Application) {
        self.container = app
    }
    
    @discardableResult
    public func on(_ method: Method, to path: PathComponentRepresentable..., use closure: @escaping Closure) -> Route {
        let responder = BasicAsyncResponder { (request: Request) -> Future<Response> in
            let typeSafeRequest = try TypeSafeRequest<Input>(request: request, for: self.container)
            
            return try closure(typeSafeRequest).map { response in
                return try response.makeResponse(for: request)
            }
        }
        
        let route = Route(method: method, path: path.makePathComponents(), responder: responder)
        routes.append(route)
        return route
    }
}

open class SyncController<Input: Codable, Output: Codable> {
    /// Responder closure
    public typealias Closure = (TypeSafeRequest<Input>) throws -> TypeSafeResponse<Output>
    
    let container: Application
    
    var routes = [Route]()
    
    init(for app: Application) {
        self.container = app
    }
    
    @discardableResult
    public func on(_ method: Method, to path: PathComponentRepresentable..., use closure: @escaping Closure) -> Route {
        let responder = BasicSyncResponder { (request: Request) -> Response in
            let typeSafeRequest = try TypeSafeRequest<Input>(request: request, for: self.container)
            
            return try closure(typeSafeRequest).makeResponse(for: request)
        }
        
        let route = Route(method: method, path: path.makePathComponents(), responder: responder)
        routes.append(route)
        return route
    }
}
