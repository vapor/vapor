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
