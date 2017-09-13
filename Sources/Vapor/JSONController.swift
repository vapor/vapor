import Core
import HTTP
import Routing

public final class TypeSafeRequest<Content: Codable> : RequestConvertible {
    public init(response: Request) throws {
        
    }
    
    public func makeRequest() throws -> Request {
        
    }
}

public final class TypeSafeResponse<Content: Codable> : ResponseConvertible {
    public init(response: Response) throws {
        
    }
    
    public func makeResponse(for request: Request) throws -> Response {
        
    }
}

open class AsyncController<Input: Codable, Output: Codable> {
    /// Responder closure
    public typealias Closure = (TypeSafeRequest<Input>) throws -> Future<TypeSafeResponse<Output>>
    
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on(_ method: Method, to path: PathComponentRepresentable..., use closure: @escaping Closure) -> Route {
        fatalError()
    }
}

open class SyncController<Input: Codable, Output: Codable> {
    /// Responder closure
    public typealias Closure = (TypeSafeRequest<Input>) throws -> TypeSafeResponse<Output>
    
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on(_ method: Method, to path: PathComponentRepresentable..., use closure: @escaping Closure) -> Route {
        fatalError()
    }
}
